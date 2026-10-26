// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/platform_providers.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../vault/providers.dart';
import '../android/widget_data.dart';
import '../model/sticky.dart';
import '../providers.dart';
import 'sticky_card.dart';

/// Screen displayed when configuring an Android single-sticky home screen widget.
class WidgetStickyPickerScreen extends ConsumerWidget {
  const WidgetStickyPickerScreen({super.key, required this.widgetId});

  final int widgetId;

  Future<void> _selectSticky({
    required BuildContext context,
    required WidgetRef ref,
    required Sticky sticky,
  }) async {
    final homeWidgets = ref.read(homeWidgetServiceProvider);
    final session = ref.read(vaultSessionProvider);
    if (session == null) return;

    final pathsRaw = await homeWidgets.readJson('sticky_widget_paths');
    final pathsMap = pathsRaw != null
        ? Map<String, Object?>.from(pathsRaw)
        : <String, Object?>{};

    pathsMap[widgetId.toString()] = sticky.path.value;
    await homeWidgets.saveJson('sticky_widget_paths', pathsMap);

    final singleJson = stickyWidgetJson(
      sticky,
      vaultId: session.vaultId,
      configured: true,
    );
    await homeWidgets.saveJson('sticky_widget_$widgetId', singleJson);
    await homeWidgets.updateStickyWidgets();

    if (context.mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        await SystemNavigator.pop();
      }
    }
  }

  Future<void> _createAndSelectNew({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final repo = ref.read(stickyRepositoryProvider);
    final sticky = await repo.create();
    if (context.mounted) {
      await _selectSticky(context: context, ref: ref, sticky: sticky);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(stickyRepositoryProvider);
    final activeStickies = repo.all;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.widgetPickerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.widgetPickerNewSticky,
            onPressed: () => _createAndSelectNew(context: context, ref: ref),
          ),
        ],
      ),
      body: activeStickies.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.widgetPickerEmpty,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.widgetPickerNewSticky),
                    onPressed: () =>
                        _createAndSelectNew(context: context, ref: ref),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisExtent: 220,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: activeStickies.length,
              itemBuilder: (context, index) {
                final sticky = activeStickies[index];
                return StickyCard(
                  title: sticky.title,
                  text: sticky.text,
                  color: sticky.meta.color,
                  locked: sticky.meta.locked,
                  pinned: sticky.meta.pinned,
                  remind: sticky.meta.remind,
                  onTap: () =>
                      _selectSticky(context: context, ref: ref, sticky: sticky),
                );
              },
            ),
    );
  }
}
