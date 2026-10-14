// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StatusBarAlignment { left, right }

final class StatusBarItemSpec {
  const StatusBarItemSpec({
    required this.id,
    required this.alignment,
    required this.builder,
    this.order = 0,
  });

  final String id;
  final StatusBarAlignment alignment;
  final Widget Function(BuildContext, WidgetRef) builder;
  final int order;
}

final class StatusBarRegistry extends Notifier<List<StatusBarItemSpec>> {
  @override
  List<StatusBarItemSpec> build() => const [];

  void register(StatusBarItemSpec spec) {
    final list = state.where((s) => s.id != spec.id).toList();
    list.add(spec);
    list.sort((a, b) => a.order.compareTo(b.order));
    state = list;
  }

  List<StatusBarItemSpec> itemsFor(StatusBarAlignment alignment) {
    final filtered = state.where((i) => i.alignment == alignment).toList();
    filtered.sort((a, b) => a.order.compareTo(b.order));
    return filtered;
  }
}

final statusBarRegistryProvider =
    NotifierProvider<StatusBarRegistry, List<StatusBarItemSpec>>(
      StatusBarRegistry.new,
    );
