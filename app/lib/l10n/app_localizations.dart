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

  /// No description provided for @commandAppOpenQuickSwitcher.
  ///
  /// In en, this message translates to:
  /// **'Open quick switcher'**
  String get commandAppOpenQuickSwitcher;

  /// No description provided for @commandAppOpenCommandPalette.
  ///
  /// In en, this message translates to:
  /// **'Open command palette'**
  String get commandAppOpenCommandPalette;

  /// No description provided for @commandAppOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get commandAppOpenSettings;

  /// No description provided for @commandAppOpenVault.
  ///
  /// In en, this message translates to:
  /// **'Open another vault…'**
  String get commandAppOpenVault;

  /// No description provided for @commandAppToggleLeftSidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle left sidebar'**
  String get commandAppToggleLeftSidebar;

  /// No description provided for @commandWorkspaceCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get commandWorkspaceCloseTab;

  /// No description provided for @commandWorkspaceNextTab.
  ///
  /// In en, this message translates to:
  /// **'Next tab'**
  String get commandWorkspaceNextTab;

  /// No description provided for @commandWorkspacePreviousTab.
  ///
  /// In en, this message translates to:
  /// **'Previous tab'**
  String get commandWorkspacePreviousTab;

  /// No description provided for @commandWorkspaceGoBack.
  ///
  /// In en, this message translates to:
  /// **'Navigate back'**
  String get commandWorkspaceGoBack;

  /// No description provided for @commandWorkspaceGoForward.
  ///
  /// In en, this message translates to:
  /// **'Navigate forward'**
  String get commandWorkspaceGoForward;

  /// No description provided for @commandWorkspaceSplitRight.
  ///
  /// In en, this message translates to:
  /// **'Split right'**
  String get commandWorkspaceSplitRight;

  /// No description provided for @commandWorkspaceSplitDown.
  ///
  /// In en, this message translates to:
  /// **'Split down'**
  String get commandWorkspaceSplitDown;

  /// No description provided for @commandWorkspaceClosePane.
  ///
  /// In en, this message translates to:
  /// **'Close split'**
  String get commandWorkspaceClosePane;

  /// No description provided for @commandEditorToggleReadingView.
  ///
  /// In en, this message translates to:
  /// **'Toggle reading view'**
  String get commandEditorToggleReadingView;

  /// No description provided for @commandNoteCreateNote.
  ///
  /// In en, this message translates to:
  /// **'Create new note'**
  String get commandNoteCreateNote;

  /// No description provided for @palettePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a command…'**
  String get palettePlaceholder;

  /// No description provided for @paletteNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching commands'**
  String get paletteNoResults;

  /// No description provided for @switcherPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a note name…'**
  String get switcherPlaceholder;

  /// Row to create new note with query name
  ///
  /// In en, this message translates to:
  /// **'Create “{name}”'**
  String switcherCreate(String name);

  /// No description provided for @switcherNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching notes'**
  String get switcherNoResults;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get settingsEditor;

  /// No description provided for @settingsFiles.
  ///
  /// In en, this message translates to:
  /// **'Files & Links'**
  String get settingsFiles;

  /// No description provided for @settingsHotkeys.
  ///
  /// In en, this message translates to:
  /// **'Hotkeys'**
  String get settingsHotkeys;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsFontSize;

  /// No description provided for @settingsUseTab.
  ///
  /// In en, this message translates to:
  /// **'Indent with tabs'**
  String get settingsUseTab;

  /// No description provided for @settingsTabSize.
  ///
  /// In en, this message translates to:
  /// **'Tab size'**
  String get settingsTabSize;

  /// No description provided for @settingsReadableLineLength.
  ///
  /// In en, this message translates to:
  /// **'Readable line length'**
  String get settingsReadableLineLength;

  /// No description provided for @settingsDefaultViewMode.
  ///
  /// In en, this message translates to:
  /// **'Default view for new tabs'**
  String get settingsDefaultViewMode;

  /// No description provided for @settingsAttachmentFolder.
  ///
  /// In en, this message translates to:
  /// **'Attachment folder'**
  String get settingsAttachmentFolder;

  /// No description provided for @settingsAttachmentFolderHelp.
  ///
  /// In en, this message translates to:
  /// **'/ = vault root, ./ = same folder as the note, ./attachments = subfolder of the note\'s folder, or a folder name'**
  String get settingsAttachmentFolderHelp;

  /// No description provided for @settingsNewNoteLocation.
  ///
  /// In en, this message translates to:
  /// **'Default location for new notes'**
  String get settingsNewNoteLocation;

  /// No description provided for @settingsNewNoteFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder for new notes'**
  String get settingsNewNoteFolder;

  /// No description provided for @settingsTrashMode.
  ///
  /// In en, this message translates to:
  /// **'Deleted files'**
  String get settingsTrashMode;

  /// No description provided for @settingsShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden folders'**
  String get settingsShowHidden;

  /// No description provided for @hotkeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Hotkeys'**
  String get hotkeysTitle;

  /// No description provided for @hotkeysSearch.
  ///
  /// In en, this message translates to:
  /// **'Filter hotkeys…'**
  String get hotkeysSearch;

  /// No description provided for @hotkeysAdd.
  ///
  /// In en, this message translates to:
  /// **'Add hotkey'**
  String get hotkeysAdd;

  /// No description provided for @hotkeysReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get hotkeysReset;

  /// No description provided for @hotkeysResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get hotkeysResetAll;

  /// No description provided for @hotkeysPressKeys.
  ///
  /// In en, this message translates to:
  /// **'Press hotkey combo…'**
  String get hotkeysPressKeys;

  /// Title for conflict warning dialog
  ///
  /// In en, this message translates to:
  /// **'Already used by {commands}'**
  String hotkeyConflictTitle(String commands);

  /// No description provided for @hotkeyReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get hotkeyReplace;

  /// No description provided for @hotkeyKeepBoth.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get hotkeyKeepBoth;

  /// No description provided for @newNoteUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get newNoteUntitled;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied to clipboard'**
  String get codeCopied;

  /// No description provided for @codeRenderedLater.
  ///
  /// In en, this message translates to:
  /// **'Rendered in a later version'**
  String get codeRenderedLater;

  /// No description provided for @footnoteMissing.
  ///
  /// In en, this message translates to:
  /// **'Undefined footnote'**
  String get footnoteMissing;

  /// No description provided for @footnotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Footnotes'**
  String get footnotesTitle;

  /// No description provided for @readingLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading note…'**
  String get readingLoading;

  /// Message shown when a link target is not found in vault
  ///
  /// In en, this message translates to:
  /// **'\"{target}\" doesn\'t exist'**
  String linkNotFound(String target);

  /// No description provided for @linkCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get linkCreate;

  /// No description provided for @linkSchemeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Opening this URL scheme is blocked for security'**
  String get linkSchemeBlocked;

  /// Placeholder for missing image
  ///
  /// In en, this message translates to:
  /// **'Image not found: {name}'**
  String imageNotFound(String name);

  /// Placeholder for missing embed
  ///
  /// In en, this message translates to:
  /// **'Embed not found: {target}'**
  String embedNotFound(String target);

  /// No description provided for @embedOpenLater.
  ///
  /// In en, this message translates to:
  /// **'Open this file type in a later version'**
  String get embedOpenLater;

  /// No description provided for @fileChipOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get fileChipOpen;

  /// No description provided for @commandNoteSave.
  ///
  /// In en, this message translates to:
  /// **'Save current note'**
  String get commandNoteSave;

  /// No description provided for @commandNoteCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'Create new folder'**
  String get commandNoteCreateFolder;

  /// No description provided for @commandNoteRenameNote.
  ///
  /// In en, this message translates to:
  /// **'Rename current note'**
  String get commandNoteRenameNote;

  /// No description provided for @commandNoteDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete current note'**
  String get commandNoteDeleteNote;

  /// No description provided for @commandNoteDuplicateNote.
  ///
  /// In en, this message translates to:
  /// **'Duplicate current note'**
  String get commandNoteDuplicateNote;

  /// No description provided for @commandNoteRevealInExplorer.
  ///
  /// In en, this message translates to:
  /// **'Reveal in system explorer'**
  String get commandNoteRevealInExplorer;

  /// No description provided for @commandExplorerCollapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all folders'**
  String get commandExplorerCollapseAll;

  /// No description provided for @commandExplorerRevealActiveFile.
  ///
  /// In en, this message translates to:
  /// **'Reveal active file in explorer'**
  String get commandExplorerRevealActiveFile;

  /// No description provided for @explorerNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get explorerNewNote;

  /// No description provided for @explorerNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get explorerNewFolder;

  /// No description provided for @explorerSort.
  ///
  /// In en, this message translates to:
  /// **'Change sort order'**
  String get explorerSort;

  /// No description provided for @explorerSortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'File name (A to Z)'**
  String get explorerSortNameAsc;

  /// No description provided for @explorerSortNameDesc.
  ///
  /// In en, this message translates to:
  /// **'File name (Z to A)'**
  String get explorerSortNameDesc;

  /// No description provided for @explorerSortModifiedNew.
  ///
  /// In en, this message translates to:
  /// **'Modified time (new to old)'**
  String get explorerSortModifiedNew;

  /// No description provided for @explorerSortModifiedOld.
  ///
  /// In en, this message translates to:
  /// **'Modified time (old to new)'**
  String get explorerSortModifiedOld;

  /// No description provided for @explorerSortCreatedNew.
  ///
  /// In en, this message translates to:
  /// **'Created time (new to old)'**
  String get explorerSortCreatedNew;

  /// No description provided for @explorerSortCreatedOld.
  ///
  /// In en, this message translates to:
  /// **'Created time (old to new)'**
  String get explorerSortCreatedOld;

  /// No description provided for @explorerCollapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get explorerCollapseAll;

  /// No description provided for @explorerOpenInNewTab.
  ///
  /// In en, this message translates to:
  /// **'Open in new tab'**
  String get explorerOpenInNewTab;

  /// No description provided for @explorerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get explorerRename;

  /// No description provided for @explorerDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get explorerDuplicate;

  /// No description provided for @explorerMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get explorerMoveTo;

  /// No description provided for @explorerMoveHere.
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get explorerMoveHere;

  /// No description provided for @explorerReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal in system explorer'**
  String get explorerReveal;

  /// No description provided for @explorerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get explorerDelete;

  /// Title for delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String explorerDeleteTitle(String name);

  /// No description provided for @explorerDeleteBodySystem.
  ///
  /// In en, this message translates to:
  /// **'It will be moved to the Recycle Bin.'**
  String get explorerDeleteBodySystem;

  /// No description provided for @explorerDeleteBodyVault.
  ///
  /// In en, this message translates to:
  /// **'It will be moved to the vault\'s .trash folder.'**
  String get explorerDeleteBodyVault;

  /// No description provided for @explorerDeleteBodyPermanent.
  ///
  /// In en, this message translates to:
  /// **'It will be deleted permanently. This cannot be undone.'**
  String get explorerDeleteBodyPermanent;

  /// Extra note in delete dialog for non-empty folder
  ///
  /// In en, this message translates to:
  /// **'All {count} items inside are included.'**
  String explorerDeleteFolderExtra(int count);

  /// No description provided for @explorerDeleteUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes in open notes will be lost.'**
  String get explorerDeleteUnsaved;

  /// No description provided for @explorerNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get explorerNameEmpty;

  /// No description provided for @explorerNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Name contains invalid characters'**
  String get explorerNameInvalid;

  /// No description provided for @explorerNameExists.
  ///
  /// In en, this message translates to:
  /// **'A file or folder with that name already exists'**
  String get explorerNameExists;

  /// No description provided for @explorerPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get explorerPermissionDenied;

  /// No description provided for @explorerNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get explorerNotFound;

  /// No description provided for @explorerMoveExists.
  ///
  /// In en, this message translates to:
  /// **'A file with that name already exists in the destination folder'**
  String get explorerMoveExists;

  /// No description provided for @explorerUntitledFolder.
  ///
  /// In en, this message translates to:
  /// **'Untitled folder'**
  String get explorerUntitledFolder;

  /// No description provided for @explorerEmpty.
  ///
  /// In en, this message translates to:
  /// **'This vault has no notes yet'**
  String get explorerEmpty;

  /// No description provided for @noteOpenElsewhere.
  ///
  /// In en, this message translates to:
  /// **'This note is being edited in another tab.'**
  String get noteOpenElsewhere;

  /// No description provided for @editorReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'This note is read-only because it contains invalid UTF-8.'**
  String get editorReadOnlyHint;

  /// No description provided for @modeReadingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to reading view'**
  String get modeReadingTooltip;

  /// No description provided for @modeSourceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to source mode'**
  String get modeSourceTooltip;

  /// No description provided for @findQueryHint.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get findQueryHint;

  /// No description provided for @findReplaceHint.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get findReplaceHint;

  /// No description provided for @findNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get findNoResults;

  /// Counter in find bar showing current match and total matches
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String findCounter(int current, int total);

  /// No description provided for @findInvalidRegex.
  ///
  /// In en, this message translates to:
  /// **'Invalid regular expression'**
  String get findInvalidRegex;

  /// Snackbar text after replace all
  ///
  /// In en, this message translates to:
  /// **'Replaced {count} occurrences'**
  String findReplacedCount(int count);

  /// No description provided for @findMatchCase.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get findMatchCase;

  /// No description provided for @findWholeWord.
  ///
  /// In en, this message translates to:
  /// **'Whole word'**
  String get findWholeWord;

  /// No description provided for @findRegex.
  ///
  /// In en, this message translates to:
  /// **'Regular expression'**
  String get findRegex;

  /// No description provided for @findNext.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get findNext;

  /// No description provided for @findPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get findPrevious;

  /// No description provided for @findClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get findClose;

  /// No description provided for @findReplaceOne.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get findReplaceOne;

  /// No description provided for @findReplaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get findReplaceAll;

  /// No description provided for @commandEditorToggleBold.
  ///
  /// In en, this message translates to:
  /// **'Toggle bold'**
  String get commandEditorToggleBold;

  /// No description provided for @commandEditorToggleItalic.
  ///
  /// In en, this message translates to:
  /// **'Toggle italic'**
  String get commandEditorToggleItalic;

  /// No description provided for @commandEditorToggleStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Toggle strikethrough'**
  String get commandEditorToggleStrikethrough;

  /// No description provided for @commandEditorToggleHighlight.
  ///
  /// In en, this message translates to:
  /// **'Toggle highlight'**
  String get commandEditorToggleHighlight;

  /// No description provided for @commandEditorToggleCode.
  ///
  /// In en, this message translates to:
  /// **'Toggle inline code'**
  String get commandEditorToggleCode;

  /// No description provided for @commandEditorInsertLink.
  ///
  /// In en, this message translates to:
  /// **'Insert link'**
  String get commandEditorInsertLink;

  /// No description provided for @commandEditorToggleBulletList.
  ///
  /// In en, this message translates to:
  /// **'Toggle bullet list'**
  String get commandEditorToggleBulletList;

  /// No description provided for @commandEditorToggleNumberedList.
  ///
  /// In en, this message translates to:
  /// **'Toggle numbered list'**
  String get commandEditorToggleNumberedList;

  /// No description provided for @commandEditorToggleTask.
  ///
  /// In en, this message translates to:
  /// **'Toggle task checkbox'**
  String get commandEditorToggleTask;

  /// No description provided for @commandEditorToggleQuote.
  ///
  /// In en, this message translates to:
  /// **'Toggle quote'**
  String get commandEditorToggleQuote;

  /// No description provided for @commandEditorCycleHeading.
  ///
  /// In en, this message translates to:
  /// **'Cycle heading level'**
  String get commandEditorCycleHeading;

  /// No description provided for @commandEditorIndentList.
  ///
  /// In en, this message translates to:
  /// **'Indent'**
  String get commandEditorIndentList;

  /// No description provided for @commandEditorOutdentList.
  ///
  /// In en, this message translates to:
  /// **'Outdent'**
  String get commandEditorOutdentList;

  /// No description provided for @commandEditorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commandEditorUndo;

  /// No description provided for @commandEditorRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get commandEditorRedo;

  /// No description provided for @commandEditorFind.
  ///
  /// In en, this message translates to:
  /// **'Find in note'**
  String get commandEditorFind;

  /// No description provided for @commandEditorReplace.
  ///
  /// In en, this message translates to:
  /// **'Find and replace in note'**
  String get commandEditorReplace;

  /// No description provided for @commandEditorMoveLineUp.
  ///
  /// In en, this message translates to:
  /// **'Move line up'**
  String get commandEditorMoveLineUp;

  /// No description provided for @commandEditorMoveLineDown.
  ///
  /// In en, this message translates to:
  /// **'Move line down'**
  String get commandEditorMoveLineDown;

  /// No description provided for @commandEditorDuplicateLine.
  ///
  /// In en, this message translates to:
  /// **'Duplicate line'**
  String get commandEditorDuplicateLine;

  /// Dialog title when an external conflict is detected
  ///
  /// In en, this message translates to:
  /// **'“{name}” changed on disk'**
  String conflictTitle(String name);

  /// No description provided for @conflictBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes and this note was also changed outside Tephra. Choose which version to keep. Nothing is lost: the version you do not keep is saved as a copy.'**
  String get conflictBody;

  /// No description provided for @conflictKeepMine.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get conflictKeepMine;

  /// No description provided for @conflictTakeTheirs.
  ///
  /// In en, this message translates to:
  /// **'Take theirs'**
  String get conflictTakeTheirs;

  /// No description provided for @conflictKeepBoth.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get conflictKeepBoth;

  /// No description provided for @noteDeletedBanner.
  ///
  /// In en, this message translates to:
  /// **'This note was deleted outside Tephra.'**
  String get noteDeletedBanner;

  /// No description provided for @noteRecreate.
  ///
  /// In en, this message translates to:
  /// **'Recreate file'**
  String get noteRecreate;

  /// No description provided for @saveStateSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saveStateSaved;

  /// No description provided for @saveStateUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get saveStateUnsaved;

  /// No description provided for @saveStateSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saveStateSaving;

  /// No description provided for @saveStateError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — tap to retry'**
  String get saveStateError;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save note'**
  String get saveFailed;

  /// No description provided for @attachmentDropHint.
  ///
  /// In en, this message translates to:
  /// **'Drop files to insert as attachments'**
  String get attachmentDropHint;

  /// No description provided for @attachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to insert attachment'**
  String get attachmentFailed;

  /// No description provided for @attachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Attachment is larger than 200 MB'**
  String get attachmentTooLarge;

  /// No description provided for @attachmentPickPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get attachmentPickPhoto;

  /// No description provided for @attachmentTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get attachmentTakePhoto;

  /// No description provided for @attachmentPickFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get attachmentPickFile;

  /// No description provided for @toolbarMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get toolbarMore;

  /// No description provided for @commandEditorHideKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Hide keyboard'**
  String get commandEditorHideKeyboard;

  /// No description provided for @commandEditorInsertAttachment.
  ///
  /// In en, this message translates to:
  /// **'Insert attachment…'**
  String get commandEditorInsertAttachment;

  /// No description provided for @indexStatusScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning vault…'**
  String get indexStatusScanning;

  /// Progress shown while indexing notes
  ///
  /// In en, this message translates to:
  /// **'Indexing {done} / {total}'**
  String indexStatusIndexing(int done, int total);

  /// No description provided for @indexStatusResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving links…'**
  String get indexStatusResolving;

  /// No description provided for @commandRebuildIndex.
  ///
  /// In en, this message translates to:
  /// **'Rebuild index'**
  String get commandRebuildIndex;

  /// No description provided for @rebuildIndexConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Rebuild index'**
  String get rebuildIndexConfirmTitle;

  /// No description provided for @rebuildIndexConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Rebuild the search index for this vault? Tephra stays usable while it runs.'**
  String get rebuildIndexConfirmBody;

  /// No description provided for @rebuildIndexDone.
  ///
  /// In en, this message translates to:
  /// **'Index rebuilt'**
  String get rebuildIndexDone;

  /// No description provided for @excludedFoldersRebuildPrompt.
  ///
  /// In en, this message translates to:
  /// **'Changing excluded folders requires rebuilding the search index. Rebuild now?'**
  String get excludedFoldersRebuildPrompt;

  /// No description provided for @settingsFilesAndLinks.
  ///
  /// In en, this message translates to:
  /// **'Files & links'**
  String get settingsFilesAndLinks;

  /// No description provided for @settingsNewLinkFormat.
  ///
  /// In en, this message translates to:
  /// **'New link format'**
  String get settingsNewLinkFormat;

  /// No description provided for @settingsNewLinkFormatShortest.
  ///
  /// In en, this message translates to:
  /// **'Shortest path when possible'**
  String get settingsNewLinkFormatShortest;

  /// No description provided for @settingsNewLinkFormatRelative.
  ///
  /// In en, this message translates to:
  /// **'Relative path to file'**
  String get settingsNewLinkFormatRelative;

  /// No description provided for @settingsNewLinkFormatAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Absolute path in vault'**
  String get settingsNewLinkFormatAbsolute;

  /// No description provided for @settingsUseWikilinks.
  ///
  /// In en, this message translates to:
  /// **'Use [[Wikilinks]]'**
  String get settingsUseWikilinks;

  /// No description provided for @settingsAlwaysUpdateLinks.
  ///
  /// In en, this message translates to:
  /// **'Automatically update internal links'**
  String get settingsAlwaysUpdateLinks;

  /// No description provided for @settingsExcludedFolders.
  ///
  /// In en, this message translates to:
  /// **'Excluded folders'**
  String get settingsExcludedFolders;

  /// No description provided for @settingsExcludedFoldersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add folder…'**
  String get settingsExcludedFoldersAdd;

  /// No description provided for @settingsExcludedFoldersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No excluded folders'**
  String get settingsExcludedFoldersEmpty;

  /// No description provided for @linkHeadingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Heading or block not found'**
  String get linkHeadingNotFound;

  /// No description provided for @linkTargetFileMissing.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" doesn\'t exist in this vault'**
  String linkTargetFileMissing(String name);

  /// No description provided for @linkInvalidTarget.
  ///
  /// In en, this message translates to:
  /// **'Invalid link target'**
  String get linkInvalidTarget;

  /// No description provided for @renameTargetExists.
  ///
  /// In en, this message translates to:
  /// **'A file or folder with that name already exists'**
  String get renameTargetExists;

  /// No description provided for @renameUpdateLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'Update links'**
  String get renameUpdateLinksTitle;

  /// Dialog prompt asking whether to update links across notes after a file rename or move
  ///
  /// In en, this message translates to:
  /// **'Update {links, plural, =1{1 link} other{{links} links}} in {files, plural, =1{1 file} other{{files} files}}?'**
  String renameUpdateLinksPrompt(int links, int files);

  /// No description provided for @renameUpdateLinksActionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get renameUpdateLinksActionUpdate;

  /// No description provided for @renameUpdateLinksActionDontUpdate.
  ///
  /// In en, this message translates to:
  /// **'Don\'t update'**
  String get renameUpdateLinksActionDontUpdate;

  /// Toast message after links are updated on rename or move
  ///
  /// In en, this message translates to:
  /// **'{links, plural, =1{Updated 1 link} other{Updated {links} links}} in {files, plural, =1{1 file} other{{files} files}}'**
  String renameLinksUpdated(int links, int files);

  /// No description provided for @undoRenameDone.
  ///
  /// In en, this message translates to:
  /// **'Undo rename completed'**
  String get undoRenameDone;

  /// Toast message after undoing a rename operation when some files conflicted
  ///
  /// In en, this message translates to:
  /// **'Undo finished; {count, plural, =1{1 file had changed and was left as it is} other{{count} files had changed and were left as they are}}'**
  String undoRenamePartial(int count);

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @commandVaultUndoLastRename.
  ///
  /// In en, this message translates to:
  /// **'Undo last rename'**
  String get commandVaultUndoLastRename;

  /// No description provided for @sidebarBacklinks.
  ///
  /// In en, this message translates to:
  /// **'Backlinks'**
  String get sidebarBacklinks;

  /// No description provided for @sidebarOutgoingLinks.
  ///
  /// In en, this message translates to:
  /// **'Outgoing links'**
  String get sidebarOutgoingLinks;

  /// No description provided for @mentionChangedRefresh.
  ///
  /// In en, this message translates to:
  /// **'The note was edited; mention list refreshed.'**
  String get mentionChangedRefresh;

  /// No description provided for @mentionLinked.
  ///
  /// In en, this message translates to:
  /// **'Mention linked'**
  String get mentionLinked;

  /// No description provided for @linkedMentionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked mentions'**
  String get linkedMentionsTitle;

  /// No description provided for @unlinkedMentionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlinked mentions'**
  String get unlinkedMentionsTitle;

  /// No description provided for @linkMentionAction.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkMentionAction;

  /// No description provided for @unresolvedLinksSection.
  ///
  /// In en, this message translates to:
  /// **'Unresolved'**
  String get unresolvedLinksSection;

  /// No description provided for @createLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createLinkAction;

  /// No description provided for @collapseAllAction.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get collapseAllAction;

  /// No description provided for @noActiveNote.
  ///
  /// In en, this message translates to:
  /// **'No active note'**
  String get noActiveNote;

  /// No description provided for @sortAlphabeticalAsc.
  ///
  /// In en, this message translates to:
  /// **'File name (A to Z)'**
  String get sortAlphabeticalAsc;

  /// No description provided for @sortAlphabeticalDesc.
  ///
  /// In en, this message translates to:
  /// **'File name (Z to A)'**
  String get sortAlphabeticalDesc;

  /// No description provided for @sortModifiedNew.
  ///
  /// In en, this message translates to:
  /// **'Modified time (new to old)'**
  String get sortModifiedNew;

  /// No description provided for @sidebarOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get sidebarOutline;

  /// No description provided for @outlineNoHeadings.
  ///
  /// In en, this message translates to:
  /// **'No headings found'**
  String get outlineNoHeadings;

  /// No description provided for @copyLinkToHeading.
  ///
  /// In en, this message translates to:
  /// **'Copy link to heading'**
  String get copyLinkToHeading;

  /// No description provided for @headingLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link to heading copied'**
  String get headingLinkCopied;

  /// No description provided for @bookmarkHeading.
  ///
  /// In en, this message translates to:
  /// **'Bookmark heading'**
  String get bookmarkHeading;

  /// No description provided for @headingBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Heading bookmarked'**
  String get headingBookmarked;

  /// No description provided for @embedTooDeep.
  ///
  /// In en, this message translates to:
  /// **'Embed depth limit reached'**
  String get embedTooDeep;

  /// No description provided for @embedCircular.
  ///
  /// In en, this message translates to:
  /// **'Circular embed'**
  String get embedCircular;

  /// No description provided for @embedSectionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Section or block not found'**
  String get embedSectionNotFound;

  /// No description provided for @embedMediaLaterPhase.
  ///
  /// In en, this message translates to:
  /// **'Playing and viewing this file type arrives in a later version'**
  String get embedMediaLaterPhase;

  /// Page preview message for unresolved note target
  ///
  /// In en, this message translates to:
  /// **'“{target}” is not created yet. Click to create.'**
  String previewNotCreated(String target);

  /// No description provided for @previewCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get previewCreate;

  /// No description provided for @searchTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTabTitle;

  /// No description provided for @searchFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchFieldHint;

  /// No description provided for @searchMatchCase.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get searchMatchCase;

  /// No description provided for @searchSortFileNameAsc.
  ///
  /// In en, this message translates to:
  /// **'File name (A to Z)'**
  String get searchSortFileNameAsc;

  /// No description provided for @searchSortFileNameDesc.
  ///
  /// In en, this message translates to:
  /// **'File name (Z to A)'**
  String get searchSortFileNameDesc;

  /// No description provided for @searchSortModifiedDesc.
  ///
  /// In en, this message translates to:
  /// **'Modified time (new to old)'**
  String get searchSortModifiedDesc;

  /// No description provided for @searchSortModifiedAsc.
  ///
  /// In en, this message translates to:
  /// **'Modified time (old to new)'**
  String get searchSortModifiedAsc;

  /// No description provided for @searchSortCreatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Created time (new to old)'**
  String get searchSortCreatedDesc;

  /// No description provided for @searchSortCreatedAsc.
  ///
  /// In en, this message translates to:
  /// **'Created time (old to new)'**
  String get searchSortCreatedAsc;

  /// No description provided for @searchCollapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse results'**
  String get searchCollapseAll;

  /// No description provided for @searchExpandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand results'**
  String get searchExpandAll;

  /// No description provided for @searchCopyResults.
  ///
  /// In en, this message translates to:
  /// **'Copy search results'**
  String get searchCopyResults;

  /// No description provided for @searchBookmarkThis.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this search'**
  String get searchBookmarkThis;

  /// Number of results found
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String searchResultCount(int count);

  /// No description provided for @searchMatchedFileName.
  ///
  /// In en, this message translates to:
  /// **'(matched file name)'**
  String get searchMatchedFileName;

  /// No description provided for @searchResultsCopied.
  ///
  /// In en, this message translates to:
  /// **'Search results copied to clipboard'**
  String get searchResultsCopied;

  /// Search query syntax error description
  ///
  /// In en, this message translates to:
  /// **'Search syntax error at character {offset}'**
  String searchSyntaxError(int offset);

  /// Header for query block showing number of matching notes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String queryBlockHeader(int count);

  /// Button in query block to show full results in search pane
  ///
  /// In en, this message translates to:
  /// **'Show all {count} results'**
  String queryBlockShowAll(int count);

  /// No description provided for @commandSearchOpen.
  ///
  /// In en, this message translates to:
  /// **'Search: Search in all files'**
  String get commandSearchOpen;

  /// No description provided for @commandSearchCopyResults.
  ///
  /// In en, this message translates to:
  /// **'Search: Copy search results'**
  String get commandSearchCopyResults;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No notes match your search.'**
  String get searchNoResults;

  /// No description provided for @searchHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchHistoryTitle;
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
