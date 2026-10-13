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

  /// Notice snackbar after file rename or move
  ///
  /// In en, this message translates to:
  /// **'Links to “{name}” were not updated. Automatic link updates arrive in a later version.'**
  String explorerLinksNotUpdatedNotice(String name);

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
