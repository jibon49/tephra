// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/hotkey_host.dart';
import '../core/deep_links/deep_link_router.dart';
import '../core/perf/perf_runner.dart';
import '../editor/save_state_indicator.dart';
import '../l10n/app_localizations.dart';
import '../stickies/providers.dart';
import '../sync_ui/status/sync_status_indicator.dart';
import '../vault/providers.dart';
import 'builtin_panels.dart';
import 'desktop_layout.dart';
import 'index_status.dart';
import 'phone_layout.dart';
import 'providers.dart';
import 'status_bar_registry.dart';

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key});

  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb && Platform.isWindows) {
        final l10n = AppLocalizations.of(context);
        final integration = ref.read(stickyDesktopIntegrationProvider);
        if (integration != null) {
          unawaited(integration.init(l10n: l10n));
        }
        unawaited(ref.read(stickyHubProvider).restoreOnStart());
      }
      ref.read(deepLinkRouterProvider).init();
      ref.read(reminderSchedulerProvider);
      ref.read(headlessConfigSyncProvider);
      ref.read(stickyWidgetSyncProvider);
      registerBuiltinPanels(ref);
      final registry = ref.read(statusBarRegistryProvider.notifier);
      registry.register(
        StatusBarItemSpec(
          id: 'status.activePath',
          alignment: StatusBarAlignment.left,
          builder: (context, ref) {
            final activePath = ref.watch(activeNotePathProvider);
            if (activePath == null) return const SizedBox.shrink();
            return Text(
              activePath.value,
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            );
          },
          order: 0,
        ),
      );
      registry.register(
        const StatusBarItemSpec(
          id: 'status.index',
          alignment: StatusBarAlignment.left,
          order: 50,
          builder: _buildIndexStatus,
        ),
      );
      registry.register(
        const StatusBarItemSpec(
          id: 'status.sync',
          alignment: StatusBarAlignment.right,
          order: 80,
          builder: _buildSyncStatus,
        ),
      );
      registry.register(
        StatusBarItemSpec(
          id: 'status.save',
          alignment: StatusBarAlignment.right,
          order: 100,
          builder: (context, ref) {
            final activePath = ref.watch(activeNotePathProvider);
            if (activePath == null) return const SizedBox.shrink();
            final doc = ref.watch(noteDocumentProvider(activePath));
            return SaveStateIndicator(doc: doc);
          },
        ),
      );
      if (const bool.fromEnvironment('TEPHRA_AUTO_BENCH')) {
        Future<void>.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;
          await runBenchmarks(context, ref);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 840;

    return HotkeyHost(
      child: FocusScope(
        child: isDesktop ? const DesktopLayout() : const PhoneLayout(),
      ),
    );
  }
}

Widget _buildIndexStatus(BuildContext context, WidgetRef ref) =>
    const IndexStatusItem();

Widget _buildSyncStatus(BuildContext context, WidgetRef ref) =>
    const SyncStatusIndicator();
