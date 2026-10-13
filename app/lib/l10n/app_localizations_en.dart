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
  String get vaultPickerRecent => 'Recent vaults';

  @override
  String get vaultPickerCreatePrivate => 'Create vault in app storage';

  @override
  String get vaultRecentMissing => 'Vault folder no longer exists';

  @override
  String get vaultRecentRemove => 'Remove from list';

  @override
  String get vaultPrivateHint =>
      'Notes in app storage are only visible to Tephra and are removed if you uninstall the app.';

  @override
  String get createVaultTitle => 'Create new vault';

  @override
  String get createVaultName => 'Vault name';

  @override
  String get createVaultLocation => 'Location';

  @override
  String get createVaultChoose => 'Choose…';

  @override
  String get createVaultCreate => 'Create';

  @override
  String get createVaultNameEmpty => 'Vault name cannot be empty.';

  @override
  String get createVaultNameInvalid =>
      'Vault name contains invalid characters.';

  @override
  String get vaultErrorMissing => 'The folder could not be found.';

  @override
  String get vaultErrorNotAFolder => 'The chosen path is not a folder.';

  @override
  String get vaultErrorNoAccess => 'Access to this folder was denied.';

  @override
  String get vaultErrorTooNew =>
      'This vault was created by a newer version of Tephra.';

  @override
  String get vaultErrorNotEmpty =>
      'The folder already exists and is not empty.';

  @override
  String get vaultImportedFromObsidian =>
      'Imported your Obsidian settings (read-only copy).';

  @override
  String get storageAccessTitle => 'Allow access to your files';

  @override
  String get storageAccessBody =>
      'Tephra stores notes as plain Markdown files in a folder you choose, so other apps like Obsidian can open the same files. Android calls this “All files access”. Tephra only reads and writes inside the vault folder you pick.';

  @override
  String get storageAccessAllow => 'Allow access';

  @override
  String get storageAccessPrivate => 'Use app storage instead';

  @override
  String get storageAccessNotNow => 'Not now';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonClose => 'Close';

  @override
  String get workspaceBack => 'Back';

  @override
  String get workspaceForward => 'Forward';

  @override
  String get workspaceEmptyTitle => 'No note open';

  @override
  String get tabClose => 'Close tab';

  @override
  String get tabCloseOthers => 'Close other tabs';

  @override
  String get tabSplitRight => 'Split right';

  @override
  String get tabSplitDown => 'Split down';

  @override
  String get noteMissing => 'Note no longer exists';

  @override
  String get noteMalformedBanner =>
      'This note contains invalid characters and cannot be read cleanly.';

  @override
  String get unsupportedFileTitle => 'Unsupported file type';

  @override
  String get openWithSystemApp => 'Open with default app';

  @override
  String get unsupportedFileAndroid =>
      'This file type cannot be previewed in Tephra.';

  @override
  String get sidebarExplorer => 'Files';

  @override
  String get phoneMenu => 'Menu';

  @override
  String get modeReading => 'Reading view';

  @override
  String get modeSource => 'Source mode';

  @override
  String get commandToggleMode => 'Toggle reading / source view';
}
