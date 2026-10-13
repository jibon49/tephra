// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';

final class TephraCommand {
  const TephraCommand({
    required this.id,
    required this.label,
    this.icon,
    this.defaultShortcuts = const [],
    required this.run,
    this.isAvailable,
    this.showInPalette = true,
    this.showInMobileToolbar = false,
  });

  final String id;
  final String Function(AppLocalizations l10n) label;
  final IconData? icon;
  final List<SingleActivator> defaultShortcuts;
  final void Function(WidgetRef ref, BuildContext context) run;
  final bool Function(WidgetRef ref)? isAvailable;
  final bool showInPalette;
  final bool showInMobileToolbar;
}
