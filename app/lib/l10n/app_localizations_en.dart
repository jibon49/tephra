// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tephra';

  @override
  String get welcomeTitle => 'Welcome to Tephra';

  @override
  String get welcomeSubtitle =>
      'Your notes are plain Markdown files in a folder you choose.';

  @override
  String get welcomeOpenVault => 'Open vault';

  @override
  String get welcomeCreateVault => 'Create new vault';

  @override
  String get comingInPhase1 => 'Coming in Phase 1';
}
