import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Application name shown in the window title and task switcher.
  ///
  /// In en, this message translates to:
  /// **'Tephra'**
  String get appTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Tephra'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your notes are plain Markdown files in a folder you choose.'**
  String get welcomeSubtitle;

  /// Button: open an existing vault folder.
  ///
  /// In en, this message translates to:
  /// **'Open vault'**
  String get welcomeOpenVault;

  /// Button: create a new, empty vault folder.
  ///
  /// In en, this message translates to:
  /// **'Create new vault'**
  String get welcomeCreateVault;

  /// Header for recent vaults section.
  ///
  /// In en, this message translates to:
  /// **'Recent vaults'**
  String get vaultPickerRecent;

  /// Button: create vault inside isolated app private storage on Android.
  ///
  /// In en, this message translates to:
  /// **'Create vault in app storage'**
  String get vaultPickerCreatePrivate;

  /// Subtitle for a recent vault path that does not exist.
  ///
  /// In en, this message translates to:
  /// **'Vault folder no longer exists'**
  String get vaultRecentMissing;

  /// Menu option to remove vault from recent list.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get vaultRecentRemove;

  /// Warning hint when creating a vault in app-private storage.
  ///
  /// In en, this message translates to:
  /// **'Notes in app storage are only visible to Tephra and are removed if you uninstall the app.'**
  String get vaultPrivateHint;

  /// Dialog title for creating a vault.
  ///
  /// In en, this message translates to:
  /// **'Create new vault'**
  String get createVaultTitle;

  /// Field label for vault name.
  ///
  /// In en, this message translates to:
  /// **'Vault name'**
  String get createVaultName;

  /// Label for folder location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get createVaultLocation;

  /// Button to choose folder.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get createVaultChoose;

  /// Action button to create vault.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createVaultCreate;

  /// Error message when vault name is empty.
  ///
  /// In en, this message translates to:
  /// **'Vault name cannot be empty.'**
  String get createVaultNameEmpty;

  /// Error message when vault name is invalid.
  ///
  /// In en, this message translates to:
  /// **'Vault name contains invalid characters.'**
  String get createVaultNameInvalid;

  /// Error when opening missing folder.
  ///
  /// In en, this message translates to:
  /// **'The folder could not be found.'**
  String get vaultErrorMissing;

  /// Error when target path is a file.
  ///
  /// In en, this message translates to:
  /// **'The chosen path is not a folder.'**
  String get vaultErrorNotAFolder;

  /// Error when lacking filesystem permissions.
  ///
  /// In en, this message translates to:
  /// **'Access to this folder was denied.'**
  String get vaultErrorNoAccess;

  /// Error when vault formatVersion > 1.
  ///
  /// In en, this message translates to:
  /// **'This vault was created by a newer version of Tephra.'**
  String get vaultErrorTooNew;

  /// Error when creating in non-empty folder.
  ///
  /// In en, this message translates to:
  /// **'The folder already exists and is not empty.'**
  String get vaultErrorNotEmpty;

  /// Snackbar notifying of Obsidian settings import.
  ///
  /// In en, this message translates to:
  /// **'Imported your Obsidian settings (read-only copy).'**
  String get vaultImportedFromObsidian;

  /// Title for Android storage access explanation.
  ///
  /// In en, this message translates to:
  /// **'Allow access to your files'**
  String get storageAccessTitle;

  /// Explanation of Android All files access.
  ///
  /// In en, this message translates to:
  /// **'Tephra stores notes as plain Markdown files in a folder you choose, so other apps like Obsidian can open the same files. Android calls this “All files access”. Tephra only reads and writes inside the vault folder you pick.'**
  String get storageAccessBody;

  /// Button to grant Android All files access.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get storageAccessAllow;

  /// Button to fall back to app-private storage.
  ///
  /// In en, this message translates to:
  /// **'Use app storage instead'**
  String get storageAccessPrivate;

  /// Button to dismiss storage access prompt.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get storageAccessNotNow;

  /// Common cancel button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Common OK button.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Common delete button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Common rename button.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// Common create button.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// Common close button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Tooltip for navigating back in tab history.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get workspaceBack;

  /// Tooltip for navigating forward in tab history.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get workspaceForward;

  /// Placeholder text when no tabs are open.
  ///
  /// In en, this message translates to:
  /// **'No note open'**
  String get workspaceEmptyTitle;

  /// Action to close the current tab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get tabClose;

  /// Action to close all tabs except the current one.
  ///
  /// In en, this message translates to:
  /// **'Close other tabs'**
  String get tabCloseOthers;

  /// Action to split pane horizontally side by side.
  ///
  /// In en, this message translates to:
  /// **'Split right'**
  String get tabSplitRight;

  /// Action to split pane vertically top and bottom.
  ///
  /// In en, this message translates to:
  /// **'Split down'**
  String get tabSplitDown;

  /// Message displayed when an open note was deleted.
  ///
  /// In en, this message translates to:
  /// **'Note no longer exists'**
  String get noteMissing;

  /// Warning banner when note text contains malformed UTF-8.
  ///
  /// In en, this message translates to:
  /// **'This note contains invalid characters and cannot be read cleanly.'**
  String get noteMalformedBanner;

  /// Header for unsupported file preview.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type'**
  String get unsupportedFileTitle;

  /// Button to launch unsupported file with default OS application.
  ///
  /// In en, this message translates to:
  /// **'Open with default app'**
  String get openWithSystemApp;

  /// Explanation for unsupported files on Android.
  ///
  /// In en, this message translates to:
  /// **'This file type cannot be previewed in Tephra.'**
  String get unsupportedFileAndroid;

  /// Label for the file explorer sidebar panel.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get sidebarExplorer;

  /// Tooltip for the phone drawer menu button.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get phoneMenu;

  /// Reading mode label.
  ///
  /// In en, this message translates to:
  /// **'Reading view'**
  String get modeReading;

  /// Source editing mode label.
  ///
  /// In en, this message translates to:
  /// **'Source mode'**
  String get modeSource;

  /// Command to switch between reading and source views.
  ///
  /// In en, this message translates to:
  /// **'Toggle reading / source view'**
  String get commandToggleMode;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
