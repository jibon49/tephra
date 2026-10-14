// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';

enum SidebarSide { left, right }

final class SidebarPanelSpec {
  const SidebarPanelSpec({
    required this.id,
    required this.side,
    this.phoneSide,
    required this.label,
    required this.icon,
    required this.builder,
    this.order = 0,
    this.phoneOrder,
  });

  final String id;
  final SidebarSide side;
  final SidebarSide? phoneSide;
  final String Function(AppLocalizations) label;
  final IconData icon;
  final Widget Function(BuildContext, WidgetRef) builder;
  final int order;
  final int? phoneOrder;
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

  List<SidebarPanelSpec> phonePanelsFor(SidebarSide side) {
    final filtered = state
        .where((p) => (p.phoneSide ?? p.side) == side)
        .toList();
    filtered.sort(
      (a, b) => (a.phoneOrder ?? a.order).compareTo(b.phoneOrder ?? b.order),
    );
    return filtered;
  }
}

final sidebarRegistryProvider =
    NotifierProvider<SidebarRegistry, List<SidebarPanelSpec>>(
      SidebarRegistry.new,
    );
