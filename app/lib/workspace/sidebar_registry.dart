// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';

enum SidebarSide { left, right }

final class SidebarPanelSpec {
  const SidebarPanelSpec({
    required this.id,
    required this.side,
    required this.label,
    required this.icon,
    required this.builder,
    this.order = 0,
  });

  final String id;
  final SidebarSide side;
  final String Function(AppLocalizations) label;
  final IconData icon;
  final Widget Function(BuildContext, WidgetRef) builder;
  final int order;
}

final class SidebarRegistry extends Notifier<List<SidebarPanelSpec>> {
  @override
  List<SidebarPanelSpec> build() => const [];

  void register(SidebarPanelSpec spec) {
    final list = state.where((s) => s.id != spec.id).toList();
    list.add(spec);
    list.sort((a, b) => a.order.compareTo(b.order));
    state = list;
  }

  List<SidebarPanelSpec> panelsFor(SidebarSide side) {
    final filtered = state.where((p) => p.side == side).toList();
    filtered.sort((a, b) => a.order.compareTo(b.order));
    return filtered;
  }
}

final sidebarRegistryProvider =
    NotifierProvider<SidebarRegistry, List<SidebarPanelSpec>>(
      SidebarRegistry.new,
    );
