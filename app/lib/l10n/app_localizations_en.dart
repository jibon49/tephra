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

  @override
  String get commandAppOpenQuickSwitcher => 'Open quick switcher';

  @override
  String get commandAppOpenCommandPalette => 'Open command palette';

  @override
  String get commandAppOpenSettings => 'Open settings';

  @override
  String get commandAppOpenVault => 'Open another vault…';

  @override
  String get commandAppToggleLeftSidebar => 'Toggle left sidebar';

  @override
  String get commandWorkspaceCloseTab => 'Close tab';

  @override
  String get commandWorkspaceNextTab => 'Next tab';

  @override
  String get commandWorkspacePreviousTab => 'Previous tab';

  @override
  String get commandWorkspaceGoBack => 'Navigate back';

  @override
  String get commandWorkspaceGoForward => 'Navigate forward';

  @override
  String get commandWorkspaceSplitRight => 'Split right';

  @override
  String get commandWorkspaceSplitDown => 'Split down';

  @override
  String get commandWorkspaceClosePane => 'Close split';

  @override
  String get commandEditorToggleReadingView => 'Toggle reading view';

  @override
  String get commandNoteCreateNote => 'Create new note';

  @override
  String get palettePlaceholder => 'Type a command…';

  @override
  String get paletteNoResults => 'No matching commands';

  @override
  String get switcherPlaceholder => 'Type a note name…';

  @override
  String switcherCreate(String name) {
    return 'Create “$name”';
  }

  @override
  String get switcherNoResults => 'No matching notes';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsEditor => 'Editor';

  @override
  String get settingsFiles => 'Files & Links';

  @override
  String get settingsHotkeys => 'Hotkeys';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsFontSize => 'Font size';

  @override
  String get settingsUseTab => 'Indent with tabs';

  @override
  String get settingsTabSize => 'Tab size';

  @override
  String get settingsReadableLineLength => 'Readable line length';

  @override
  String get settingsDefaultViewMode => 'Default view for new tabs';

  @override
  String get settingsAttachmentFolder => 'Attachment folder';

  @override
  String get settingsAttachmentFolderHelp =>
      '/ = vault root, ./ = same folder as the note, ./attachments = subfolder of the note\'s folder, or a folder name';

  @override
  String get settingsNewNoteLocation => 'Default location for new notes';

  @override
  String get settingsNewNoteFolder => 'Folder for new notes';

  @override
  String get settingsTrashMode => 'Deleted files';

  @override
  String get settingsShowHidden => 'Show hidden folders';

  @override
  String get hotkeysTitle => 'Hotkeys';

  @override
  String get hotkeysSearch => 'Filter hotkeys…';

  @override
  String get hotkeysAdd => 'Add hotkey';

  @override
  String get hotkeysReset => 'Reset';

  @override
  String get hotkeysResetAll => 'Reset all';

  @override
  String get hotkeysPressKeys => 'Press hotkey combo…';

  @override
  String hotkeyConflictTitle(String commands) {
    return 'Already used by $commands';
  }

  @override
  String get hotkeyReplace => 'Replace';

  @override
  String get hotkeyKeepBoth => 'Keep both';

  @override
  String get newNoteUntitled => 'Untitled';

  @override
  String get codeCopied => 'Code copied to clipboard';

  @override
  String get codeRenderedLater => 'Rendered in a later version';

  @override
  String get footnoteMissing => 'Undefined footnote';

  @override
  String get footnotesTitle => 'Footnotes';

  @override
  String get readingLoading => 'Loading note…';

  @override
  String linkNotFound(String target) {
    return '\"$target\" doesn\'t exist';
  }

  @override
  String get linkCreate => 'Create';

  @override
  String get linkSchemeBlocked =>
      'Opening this URL scheme is blocked for security';

  @override
  String imageNotFound(String name) {
    return 'Image not found: $name';
  }

  @override
  String embedNotFound(String target) {
    return 'Embed not found: $target';
  }

  @override
  String get embedOpenLater => 'Open this file type in a later version';

  @override
  String get fileChipOpen => 'Open';

  @override
  String get commandNoteSave => 'Save current note';

  @override
  String get commandNoteCreateFolder => 'Create new folder';

  @override
  String get commandNoteRenameNote => 'Rename current note';

  @override
  String get commandNoteDeleteNote => 'Delete current note';

  @override
  String get commandNoteDuplicateNote => 'Duplicate current note';

  @override
  String get commandNoteRevealInExplorer => 'Reveal in system explorer';

  @override
  String get commandExplorerCollapseAll => 'Collapse all folders';

  @override
  String get commandExplorerRevealActiveFile =>
      'Reveal active file in explorer';

  @override
  String get explorerNewNote => 'New note';

  @override
  String get explorerNewFolder => 'New folder';

  @override
  String get explorerSort => 'Change sort order';

  @override
  String get explorerSortNameAsc => 'File name (A to Z)';

  @override
  String get explorerSortNameDesc => 'File name (Z to A)';

  @override
  String get explorerSortModifiedNew => 'Modified time (new to old)';

  @override
  String get explorerSortModifiedOld => 'Modified time (old to new)';

  @override
  String get explorerSortCreatedNew => 'Created time (new to old)';

  @override
  String get explorerSortCreatedOld => 'Created time (old to new)';

  @override
  String get explorerCollapseAll => 'Collapse all';

  @override
  String get explorerOpenInNewTab => 'Open in new tab';

  @override
  String get explorerRename => 'Rename';

  @override
  String get explorerDuplicate => 'Duplicate';

  @override
  String get explorerMoveTo => 'Move to…';

  @override
  String get explorerMoveHere => 'Move here';

  @override
  String get explorerReveal => 'Reveal in system explorer';

  @override
  String get explorerDelete => 'Delete';

  @override
  String explorerDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get explorerDeleteBodySystem => 'It will be moved to the Recycle Bin.';

  @override
  String get explorerDeleteBodyVault =>
      'It will be moved to the vault\'s .trash folder.';

  @override
  String get explorerDeleteBodyPermanent =>
      'It will be deleted permanently. This cannot be undone.';

  @override
  String explorerDeleteFolderExtra(int count) {
    return 'All $count items inside are included.';
  }

  @override
  String get explorerDeleteUnsaved =>
      'Unsaved changes in open notes will be lost.';

  @override
  String get explorerNameEmpty => 'Name cannot be empty';

  @override
  String get explorerNameInvalid => 'Name contains invalid characters';

  @override
  String get explorerNameExists =>
      'A file or folder with that name already exists';

  @override
  String get explorerPermissionDenied => 'Permission denied';

  @override
  String get explorerNotFound => 'File not found';

  @override
  String get explorerMoveExists =>
      'A file with that name already exists in the destination folder';

  @override
  String get explorerUntitledFolder => 'Untitled folder';

  @override
  String get explorerEmpty => 'This vault has no notes yet';

  @override
  String get noteOpenElsewhere => 'This note is being edited in another tab.';

  @override
  String get editorReadOnlyHint =>
      'This note is read-only because it contains invalid UTF-8.';

  @override
  String get modeReadingTooltip => 'Switch to reading view';

  @override
  String get modeSourceTooltip => 'Switch to source mode';

  @override
  String get findQueryHint => 'Find';

  @override
  String get findReplaceHint => 'Replace';

  @override
  String get findNoResults => 'No results';

  @override
  String findCounter(int current, int total) {
    return '$current of $total';
  }

  @override
  String get findInvalidRegex => 'Invalid regular expression';

  @override
  String findReplacedCount(int count) {
    return 'Replaced $count occurrences';
  }

  @override
  String get findMatchCase => 'Match case';

  @override
  String get findWholeWord => 'Whole word';

  @override
  String get findRegex => 'Regular expression';

  @override
  String get findNext => 'Next match';

  @override
  String get findPrevious => 'Previous match';

  @override
  String get findClose => 'Close';

  @override
  String get findReplaceOne => 'Replace';

  @override
  String get findReplaceAll => 'Replace all';

  @override
  String get commandEditorToggleBold => 'Toggle bold';

  @override
  String get commandEditorToggleItalic => 'Toggle italic';

  @override
  String get commandEditorToggleStrikethrough => 'Toggle strikethrough';

  @override
  String get commandEditorToggleHighlight => 'Toggle highlight';

  @override
  String get commandEditorToggleCode => 'Toggle inline code';

  @override
  String get commandEditorInsertLink => 'Insert link';

  @override
  String get commandEditorToggleBulletList => 'Toggle bullet list';

  @override
  String get commandEditorToggleNumberedList => 'Toggle numbered list';

  @override
  String get commandEditorToggleTask => 'Toggle task checkbox';

  @override
  String get commandEditorToggleQuote => 'Toggle quote';

  @override
  String get commandEditorCycleHeading => 'Cycle heading level';

  @override
  String get commandEditorIndentList => 'Indent';

  @override
  String get commandEditorOutdentList => 'Outdent';

  @override
  String get commandEditorUndo => 'Undo';

  @override
  String get commandEditorRedo => 'Redo';

  @override
  String get commandEditorFind => 'Find in note';

  @override
  String get commandEditorReplace => 'Find and replace in note';

  @override
  String get commandEditorMoveLineUp => 'Move line up';

  @override
  String get commandEditorMoveLineDown => 'Move line down';

  @override
  String get commandEditorDuplicateLine => 'Duplicate line';

  @override
  String conflictTitle(String name) {
    return '“$name” changed on disk';
  }

  @override
  String get conflictBody =>
      'You have unsaved changes and this note was also changed outside Tephra. Choose which version to keep. Nothing is lost: the version you do not keep is saved as a copy.';

  @override
  String get conflictKeepMine => 'Keep mine';

  @override
  String get conflictTakeTheirs => 'Take theirs';

  @override
  String get conflictKeepBoth => 'Keep both';

  @override
  String get noteDeletedBanner => 'This note was deleted outside Tephra.';

  @override
  String get noteRecreate => 'Recreate file';

  @override
  String get saveStateSaved => 'Saved';

  @override
  String get saveStateUnsaved => 'Unsaved changes';

  @override
  String get saveStateSaving => 'Saving…';

  @override
  String get saveStateError => 'Couldn\'t save — tap to retry';

  @override
  String get saveFailed => 'Failed to save note';

  @override
  String get attachmentDropHint => 'Drop files to insert as attachments';

  @override
  String get attachmentFailed => 'Failed to insert attachment';

  @override
  String get attachmentTooLarge => 'Attachment is larger than 200 MB';

  @override
  String get attachmentPickPhoto => 'Photo library';

  @override
  String get attachmentTakePhoto => 'Take photo';

  @override
  String get attachmentPickFile => 'File';

  @override
  String get toolbarMore => 'More';

  @override
  String get commandEditorHideKeyboard => 'Hide keyboard';

  @override
  String get commandEditorInsertAttachment => 'Insert attachment…';

  @override
  String get indexStatusScanning => 'Scanning vault…';

  @override
  String indexStatusIndexing(int done, int total) {
    return 'Indexing $done / $total';
  }

  @override
  String get indexStatusResolving => 'Resolving links…';

  @override
  String get commandRebuildIndex => 'Rebuild index';

  @override
  String get rebuildIndexConfirmTitle => 'Rebuild index';

  @override
  String get rebuildIndexConfirmBody =>
      'Rebuild the search index for this vault? Tephra stays usable while it runs.';

  @override
  String get rebuildIndexDone => 'Index rebuilt';

  @override
  String get excludedFoldersRebuildPrompt =>
      'Changing excluded folders requires rebuilding the search index. Rebuild now?';

  @override
  String get settingsFilesAndLinks => 'Files & links';

  @override
  String get settingsNewLinkFormat => 'New link format';

  @override
  String get settingsNewLinkFormatShortest => 'Shortest path when possible';

  @override
  String get settingsNewLinkFormatRelative => 'Relative path to file';

  @override
  String get settingsNewLinkFormatAbsolute => 'Absolute path in vault';

  @override
  String get settingsUseWikilinks => 'Use [[Wikilinks]]';

  @override
  String get settingsAlwaysUpdateLinks => 'Automatically update internal links';

  @override
  String get settingsExcludedFolders => 'Excluded folders';

  @override
  String get settingsExcludedFoldersAdd => 'Add folder…';

  @override
  String get settingsExcludedFoldersEmpty => 'No excluded folders';

  @override
  String get linkHeadingNotFound => 'Heading or block not found';

  @override
  String linkTargetFileMissing(String name) {
    return '\"$name\" doesn\'t exist in this vault';
  }

  @override
  String get linkInvalidTarget => 'Invalid link target';

  @override
  String get renameTargetExists =>
      'A file or folder with that name already exists';

  @override
  String get renameUpdateLinksTitle => 'Update links';

  @override
  String renameUpdateLinksPrompt(int links, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      links,
      locale: localeName,
      other: '$links links',
      one: '1 link',
    );
    String _temp1 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files files',
      one: '1 file',
    );
    return 'Update $_temp0 in $_temp1?';
  }

  @override
  String get renameUpdateLinksActionUpdate => 'Update';

  @override
  String get renameUpdateLinksActionDontUpdate => 'Don\'t update';

  @override
  String renameLinksUpdated(int links, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      links,
      locale: localeName,
      other: 'Updated $links links',
      one: 'Updated 1 link',
    );
    String _temp1 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files files',
      one: '1 file',
    );
    return '$_temp0 in $_temp1';
  }

  @override
  String get undoRenameDone => 'Undo rename completed';

  @override
  String undoRenamePartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files had changed and were left as they are',
      one: '1 file had changed and was left as it is',
    );
    return 'Undo finished; $_temp0';
  }

  @override
  String get undoAction => 'Undo';

  @override
  String get commandVaultUndoLastRename => 'Undo last rename';

  @override
  String get sidebarBacklinks => 'Backlinks';

  @override
  String get sidebarOutgoingLinks => 'Outgoing links';

  @override
  String get mentionChangedRefresh =>
      'The note was edited; mention list refreshed.';

  @override
  String get mentionLinked => 'Mention linked';

  @override
  String get linkedMentionsTitle => 'Linked mentions';

  @override
  String get unlinkedMentionsTitle => 'Unlinked mentions';

  @override
  String get linkMentionAction => 'Link';

  @override
  String get unresolvedLinksSection => 'Unresolved';

  @override
  String get createLinkAction => 'Create';

  @override
  String get collapseAllAction => 'Collapse all';

  @override
  String get noActiveNote => 'No active note';

  @override
  String get sortAlphabeticalAsc => 'File name (A to Z)';

  @override
  String get sortAlphabeticalDesc => 'File name (Z to A)';

  @override
  String get sortModifiedNew => 'Modified time (new to old)';

  @override
  String get sidebarOutline => 'Outline';

  @override
  String get outlineNoHeadings => 'No headings found';

  @override
  String get copyLinkToHeading => 'Copy link to heading';

  @override
  String get headingLinkCopied => 'Link to heading copied';

  @override
  String get bookmarkHeading => 'Bookmark heading';

  @override
  String get headingBookmarked => 'Heading bookmarked';

  @override
  String get embedTooDeep => 'Embed depth limit reached';

  @override
  String get embedCircular => 'Circular embed';

  @override
  String get embedSectionNotFound => 'Section or block not found';

  @override
  String get embedMediaLaterPhase =>
      'Playing and viewing this file type arrives in a later version';

  @override
  String previewNotCreated(String target) {
    return '“$target” is not created yet. Click to create.';
  }

  @override
  String get previewCreate => 'Create';

  @override
  String get searchTabTitle => 'Search';

  @override
  String get searchFieldHint => 'Search…';

  @override
  String get searchMatchCase => 'Match case';

  @override
  String get searchSortFileNameAsc => 'File name (A to Z)';

  @override
  String get searchSortFileNameDesc => 'File name (Z to A)';

  @override
  String get searchSortModifiedDesc => 'Modified time (new to old)';

  @override
  String get searchSortModifiedAsc => 'Modified time (old to new)';

  @override
  String get searchSortCreatedDesc => 'Created time (new to old)';

  @override
  String get searchSortCreatedAsc => 'Created time (old to new)';

  @override
  String get searchCollapseAll => 'Collapse results';

  @override
  String get searchExpandAll => 'Expand results';

  @override
  String get searchCopyResults => 'Copy search results';

  @override
  String get searchBookmarkThis => 'Bookmark this search';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get searchMatchedFileName => '(matched file name)';

  @override
  String get searchResultsCopied => 'Search results copied to clipboard';

  @override
  String searchSyntaxError(int offset) {
    return 'Search syntax error at character $offset';
  }

  @override
  String queryBlockHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String queryBlockShowAll(int count) {
    return 'Show all $count results';
  }

  @override
  String get commandSearchOpen => 'Search: Search in all files';

  @override
  String get commandSearchCopyResults => 'Search: Copy search results';

  @override
  String get searchNoResults => 'No notes match your search.';

  @override
  String get searchHistoryTitle => 'Recent searches';

  @override
  String get sidebarTags => 'Tags';

  @override
  String get sidebarBookmarks => 'Bookmarks';

  @override
  String get tagSortNameAZ => 'Name (A to Z)';

  @override
  String get tagSortFrequency => 'Frequency (high to low)';

  @override
  String get tagShowNested => 'Show nested tags';

  @override
  String get tagShowFlat => 'Show flat list';

  @override
  String get tagNoTags => 'No tags found in vault';

  @override
  String get bookmarkCurrentFile => 'Bookmark current file';

  @override
  String get bookmarkRemoveCurrentFile => 'Remove bookmark';

  @override
  String get bookmarkFileAdded => 'File bookmarked';

  @override
  String get bookmarkFileRemoved => 'Bookmark removed';

  @override
  String get bookmarkAddSearch => 'Bookmark this search';

  @override
  String get bookmarkSearchAdded => 'Search bookmarked';

  @override
  String get bookmarkNewGroup => 'New bookmark group';

  @override
  String get bookmarkRename => 'Rename';

  @override
  String get bookmarkRemove => 'Remove';

  @override
  String get bookmarkMoveUp => 'Move up';

  @override
  String get bookmarkMoveDown => 'Move down';

  @override
  String get bookmarkMoveToGroup => 'Move to group...';

  @override
  String get bookmarkNoBookmarks => 'No bookmarks yet';

  @override
  String get bookmarkGroupPrompt => 'Group name';

  @override
  String get bookmarkRenamePrompt => 'Bookmark title';

  @override
  String get bookmarkCreate => 'Create';

  @override
  String get bookmarkCancel => 'Cancel';

  @override
  String get bookmarkSave => 'Save';

  @override
  String get bookmarkRoot => 'Root';

  @override
  String get commandBookmarkToggle => 'Bookmarks: Bookmark current file';

  @override
  String get commandBookmarkHeading => 'Bookmarks: Bookmark heading';

  @override
  String get commandBookmarkSearch => 'Bookmarks: Bookmark this search';

  @override
  String get commandBookmarkNewGroup => 'Bookmarks: New bookmark group';

  @override
  String get autocompleteNoResults => 'No results';

  @override
  String get autocompleteContinue => 'Continue into subpath';

  @override
  String autocompleteBlockCreated(String id) {
    return 'Added block ID ^$id';
  }

  @override
  String get autocompleteBlockMissing => 'Target block not found';

  @override
  String get commandTriggerAutocomplete => 'Trigger autocomplete';

  @override
  String get slashHeading1 => 'Heading 1';

  @override
  String get slashHeading2 => 'Heading 2';

  @override
  String get slashHeading3 => 'Heading 3';

  @override
  String get slashHeading4 => 'Heading 4';

  @override
  String get slashHeading5 => 'Heading 5';

  @override
  String get slashHeading6 => 'Heading 6';

  @override
  String get slashCalloutNote => 'Callout: Note';

  @override
  String get slashCalloutAbstract => 'Callout: Abstract';

  @override
  String get slashCalloutInfo => 'Callout: Info';

  @override
  String get slashCalloutTodo => 'Callout: To-do';

  @override
  String get slashCalloutTip => 'Callout: Tip';

  @override
  String get slashCalloutSuccess => 'Callout: Success';

  @override
  String get slashCalloutQuestion => 'Callout: Question';

  @override
  String get slashCalloutWarning => 'Callout: Warning';

  @override
  String get slashCalloutFailure => 'Callout: Failure';

  @override
  String get slashCalloutDanger => 'Callout: Danger';

  @override
  String get slashCalloutBug => 'Callout: Bug';

  @override
  String get slashCalloutExample => 'Callout: Example';

  @override
  String get slashCalloutQuote => 'Callout: Quote';

  @override
  String get slashTable => 'Table (3 × 3)';

  @override
  String get slashCodeBlock => 'Code block';

  @override
  String get slashMathBlock => 'Math block';

  @override
  String get slashHorizontalRule => 'Horizontal rule';

  @override
  String get slashTask => 'Task';

  @override
  String get slashToday => 'Today\'s date';

  @override
  String get slashTemplate => 'Insert template';

  @override
  String get commandToggleEditingMode => 'Toggle Live Preview / Source mode';

  @override
  String get editingModeLivePreview => 'Live Preview';

  @override
  String get editingModeSource => 'Source mode';

  @override
  String get settingEditorDefaultEditingMode => 'Default editing mode';

  @override
  String get settingEditorFoldHeadings => 'Fold heading';

  @override
  String get settingEditorFoldIndent => 'Fold indent';

  @override
  String get commandToggleFold => 'Toggle fold';

  @override
  String get commandFoldAll => 'Fold all';

  @override
  String get commandUnfoldAll => 'Unfold all';

  @override
  String get propertiesTitle => 'Properties';

  @override
  String get propertiesAdd => 'Add property';

  @override
  String get propertiesRemove => 'Remove property';

  @override
  String get propertiesMoveUp => 'Move up';

  @override
  String get propertiesMoveDown => 'Move down';

  @override
  String get propertiesChangeType => 'Change type';

  @override
  String get propertiesEditAsYaml => 'Edit as YAML';

  @override
  String get propertiesKeyExists => 'Property already exists';

  @override
  String get propertiesInvalidTag => 'Invalid tag';

  @override
  String get propertiesInvalidNumber => 'Invalid number';

  @override
  String get propertiesInvalidYaml => 'Invalid YAML frontmatter';

  @override
  String get propertiesApply => 'Apply';

  @override
  String get propertiesRevert => 'Revert';

  @override
  String get propertiesConvertFailed => 'Cannot convert to type, value kept';

  @override
  String get propertiesUnsupportedValue => 'Unsupported value';

  @override
  String get propertyTypeText => 'Text';

  @override
  String get propertyTypeMultitext => 'List';

  @override
  String get propertyTypeNumber => 'Number';

  @override
  String get propertyTypeCheckbox => 'Checkbox';

  @override
  String get propertyTypeDate => 'Date';

  @override
  String get propertyTypeDatetime => 'Date & time';

  @override
  String get propertyTypeAliases => 'Aliases';

  @override
  String get propertyTypeTags => 'Tags';

  @override
  String get settingEditorPropertiesInDocument => 'Properties in document';

  @override
  String get propertiesInDocumentVisible => 'Visible';

  @override
  String get propertiesInDocumentHidden => 'Hidden';

  @override
  String get propertiesInDocumentSource => 'Source';

  @override
  String get commandOpenToday => 'Open today\'s daily note';

  @override
  String get commandOpenPreviousDaily => 'Open previous daily note';

  @override
  String get commandOpenNextDaily => 'Open next daily note';

  @override
  String get commandInsertTemplate => 'Insert template';

  @override
  String get commandCreateUniqueNote => 'Create unique note';

  @override
  String get dailyFormatInvalid => 'Daily note format is invalid';

  @override
  String get dailyTemplateMissing => 'Daily note template file is missing';

  @override
  String get dailyNoNeighbour => 'No daily note found in that direction';

  @override
  String get templatesFolderNotSet => 'Templates folder is not configured';

  @override
  String get templateUnreadable => 'Template file could not be read';

  @override
  String get settingsDailyNotes => 'Daily notes';

  @override
  String get settingsTemplates => 'Templates';

  @override
  String get settingsUniqueNote => 'Unique note creator';

  @override
  String get settingDailyFormat => 'Date format';

  @override
  String get settingDailyFolder => 'New file location';

  @override
  String get settingDailyTemplate => 'Template file location';

  @override
  String get settingDailyOpenOnStartup => 'Open on startup';

  @override
  String get settingTemplatesFolder => 'Template folder location';

  @override
  String get settingTemplatesDateFormat => 'Date format';

  @override
  String get settingTemplatesTimeFormat => 'Time format';

  @override
  String get settingUniquePrefix => 'Unique note prefix';

  @override
  String settingFormatPreview(String preview) {
    return 'Preview: $preview';
  }

  @override
  String get openSettings => 'Open settings';

  @override
  String get indexUnavailableOnWeb =>
      'Search and links are not available in the web preview.';

  @override
  String get commandRunBenchmarks => 'Run performance benchmarks';

  @override
  String get syncErrorNoOAuthConfig =>
      'This build has no Google sign-in configuration.';

  @override
  String get trayTooltipUpToDate => 'Tephra — Up to date';

  @override
  String trayTooltipSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files…',
      one: '1 file…',
    );
    return 'Tephra — Syncing $_temp0';
  }

  @override
  String get trayTooltipOffline => 'Tephra — Offline';

  @override
  String get trayTooltipNeedsAttention => 'Tephra — Needs attention';

  @override
  String get trayMenuOpen => 'Open Tephra';

  @override
  String get trayMenuSyncNow => 'Sync now';

  @override
  String get trayMenuPauseSync => 'Pause sync';

  @override
  String get trayMenuResumeSync => 'Resume sync';

  @override
  String get trayMenuQuit => 'Quit Tephra';

  @override
  String get syncNotificationReconnectTitle => 'Tephra sync';

  @override
  String get syncNotificationReconnectBody =>
      'Tephra sync needs you to reconnect Google Drive';

  @override
  String get syncSetupTitle => 'Set up sync';

  @override
  String get syncSetupSignInExplain =>
      'Tephra stores your vault in a folder named Tephra in your Google Drive. With encryption on, Google cannot read your notes or file names.';

  @override
  String get syncSetupSignInButton => 'Sign in with Google';

  @override
  String syncSetupSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get syncSetupUseAnotherAccount => 'Use another account';

  @override
  String get syncSetupChooseTitle => 'Choose remote vault';

  @override
  String get syncSetupCreateNew => 'Create a new remote vault';

  @override
  String syncSetupRemoteVaultCreated(String date) {
    return 'Created $date';
  }

  @override
  String get syncSetupEncryptToggle => 'Encrypt (recommended)';

  @override
  String get syncSetupPassword => 'Vault password';

  @override
  String get syncSetupPasswordConfirm => 'Confirm password';

  @override
  String get syncSetupPasswordTooShort =>
      'Password must be at least 10 characters';

  @override
  String get syncSetupPasswordMismatch => 'Passwords do not match';

  @override
  String get syncSetupPasswordWarning =>
      'If you lose both your password and your recovery key, nobody — including Tephra — can recover your synced data. Your notes on this device are not affected.';

  @override
  String get syncSetupEncryptionOffConfirm =>
      'Turning encryption off means note contents and titles will be readable in your Google Drive. Are you sure?';

  @override
  String get syncSetupDeviceName => 'Device name';

  @override
  String get syncSetupCreating =>
      'Securing your vault… this can take a few seconds';

  @override
  String get syncSetupRecoveryTitle => 'Save your recovery key';

  @override
  String get syncSetupRecoveryExplain =>
      'If you forget your password, this recovery key is the only way to access your encrypted sync data. Store it somewhere safe.';

  @override
  String get syncSetupCopy => 'Copy key';

  @override
  String get syncSetupSaveToFile => 'Save as text file';

  @override
  String get syncSetupRecoverySavedCheckbox =>
      'I have saved my recovery key somewhere safe';

  @override
  String get syncSetupConfirmRecoveryTitle => 'Confirm your recovery key';

  @override
  String syncSetupConfirmRecoveryGroup(int number) {
    return 'Group $number';
  }

  @override
  String get syncSetupConfirmRecoveryWrong =>
      'The entered groups do not match your recovery key.';

  @override
  String get syncSetupShowKeyAgain => 'Show the key again';

  @override
  String get syncSetupUnlockTitle => 'Unlock remote vault';

  @override
  String get syncSetupUseRecoveryKey => 'Use recovery key instead';

  @override
  String get syncSetupUsePassword => 'Use password instead';

  @override
  String get syncErrorWrongPassword => 'Incorrect password.';

  @override
  String get syncErrorWrongRecoveryKey => 'Incorrect recovery key.';

  @override
  String get syncSetupFirstSyncTitle => 'First sync options';

  @override
  String syncSetupUploadOption(int count, String size) {
    return 'Upload this vault ($count files, $size)';
  }

  @override
  String get syncSetupDownloadOption => 'Download the vault';

  @override
  String get syncSetupMergeOption => 'Merge both (recommended)';

  @override
  String get syncSetupMergeExplain =>
      'Files that exist on both sides with different content are kept twice; nothing is overwritten or deleted.';

  @override
  String get syncSetupNewFolderOption => 'Download into a new empty folder';

  @override
  String get syncSetupBackgroundSync => 'Sync in background';

  @override
  String get syncSetupWifiOnly => 'Sync over Wi-Fi only';

  @override
  String get syncSetupMobileMode => 'Mobile mode (skip large videos)';

  @override
  String syncSetupProgress(
    int done,
    int total,
    String bytesDone,
    String bytesTotal,
  ) {
    return '$done of $total files · $bytesDone of $bytesTotal';
  }

  @override
  String get syncSetupRunInBackground => 'Run in background';

  @override
  String get syncSetupDoneTitle => 'Sync setup complete!';

  @override
  String get syncSetupEnableDailyBackup => 'Turn on daily backups';

  @override
  String get syncReconnectBanner =>
      'Google Drive access expired. Reconnect to keep syncing.';

  @override
  String get syncReconnectButton => 'Reconnect';

  @override
  String get syncDisconnect => 'Stop syncing this vault';

  @override
  String get syncDisconnectConfirm =>
      'Are you sure you want to stop syncing this vault on this device? Your local notes and remote data will remain untouched.';

  @override
  String get syncDisconnectAlsoSignOut =>
      'Also sign out of Google on this device';

  @override
  String get syncNotAvailableOnWeb =>
      'Sync is not available in the web preview.';

  @override
  String get syncSettingsTitle => 'Sync & backup';

  @override
  String get syncSetupAction => 'Set up sync';

  @override
  String get syncSetupCreateNewSubtitle =>
      'Start fresh synchronization in Google Drive';

  @override
  String get syncSetupExistingVaults => 'Existing remote vaults';

  @override
  String get syncSetupVaultName => 'Vault name';

  @override
  String get syncSetupEncryptSubtitle => 'End-to-end zero-knowledge encryption';

  @override
  String get syncSetupEncryptionOffTitle => 'Turn off encryption?';

  @override
  String get syncSetupKeepEncryption => 'Keep encryption';

  @override
  String get syncSetupTurnOffEncryption => 'Turn off';

  @override
  String get syncSetupCreateAndContinue => 'Create and continue';

  @override
  String get syncSetupKeyCopied => 'Recovery key copied to clipboard';

  @override
  String get syncSetupContinue => 'Continue';

  @override
  String get syncSetupConfirmRecoveryExplain =>
      'To ensure you can recover your data if needed, please enter groups 2 and 7 from your recovery key.';

  @override
  String get syncSetupVerifyAndContinue => 'Verify and continue';

  @override
  String get syncSetupRecoveryKeyLabel => 'Recovery key';

  @override
  String get syncSetupRecoveryKeyHint =>
      'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX';

  @override
  String get syncSetupUnlockButton => 'Unlock';

  @override
  String get syncSetupUploadSubtitle =>
      'Upload current local files to initialize remote vault';

  @override
  String get syncSetupDownloadSubtitle =>
      'Download all notes from the remote vault into this folder';

  @override
  String get syncSetupNewFolderSubtitle =>
      'Keep local files separate by downloading into a new folder';

  @override
  String get syncSetupChooseFolder => 'Choose folder';

  @override
  String get syncSetupBackgroundSyncSubtitle =>
      'Periodically sync in background via WorkManager';

  @override
  String get syncSetupWifiOnlySubtitle => 'Avoid mobile data consumption';

  @override
  String get syncSetupMobileModeSubtitle =>
      'Exclude large video and media files on phone';

  @override
  String get syncSetupStartSync => 'Start sync';

  @override
  String get syncSetupProgressTitle => 'Initial synchronization';

  @override
  String get syncSetupRetry => 'Retry';

  @override
  String get syncSetupSummaryUploaded => 'Uploaded files:';

  @override
  String get syncSetupSummaryDownloaded => 'Downloaded files:';

  @override
  String get syncSetupSummaryMerged => 'Merged files:';

  @override
  String get syncSetupDailyBackupSubtitle =>
      'Keep automatic local snapshots in .tephra/history';

  @override
  String get commandSyncOpenSettings => 'Sync: Open settings';

  @override
  String get syncSettingsConfiguredStatus => 'Syncing via Google Drive';

  @override
  String get syncSettingsConfigureButton => 'Configure sync';

  @override
  String get syncDisconnectSuccess => 'Sync has been disabled for this vault.';

  @override
  String get syncStatusNotConfigured => 'Not configured';

  @override
  String get syncStatusUpToDate => 'Up to date';

  @override
  String syncStatusSyncing(String done, String total) {
    return 'Syncing ($done/$total)';
  }

  @override
  String syncStatusPending(int count) {
    return '$count pending';
  }

  @override
  String get syncStatusOffline => 'Offline';

  @override
  String get syncStatusPaused => 'Sync paused';

  @override
  String get syncStatusNeedsAttention => 'Needs attention';

  @override
  String get syncStatusError => 'Sync error';

  @override
  String syncPanelLastSynced(String when) {
    return 'Last synced $when';
  }

  @override
  String syncPanelDriveUsage(String used, String total) {
    return '$used of $total used in Google Drive';
  }

  @override
  String get syncPanelSyncNow => 'Sync now';

  @override
  String get syncPanelPause => 'Pause sync';

  @override
  String get syncPanelResume => 'Resume sync';

  @override
  String syncPanelConflicts(int count) {
    return 'Conflicts ($count)';
  }

  @override
  String syncPanelHeldDeletes(int count) {
    return 'Held deletions ($count)';
  }

  @override
  String get syncPanelLog => 'Sync log';

  @override
  String get syncPanelSettings => 'Sync settings';

  @override
  String get syncHeldDeletesTitle => 'Review held deletions';

  @override
  String syncHeldDeletesExplain(int count) {
    return 'Sync wants to delete $count files because they were deleted on another device or on this device. Check before continuing.';
  }

  @override
  String get syncHeldDeletesDelete => 'Delete them';

  @override
  String get syncHeldDeletesKeep => 'Keep them';

  @override
  String get syncHeldDeletesApply => 'Apply choices';

  @override
  String get syncLogTitle => 'Sync log';

  @override
  String syncLogUploaded(String path) {
    return 'Uploaded $path';
  }

  @override
  String syncLogDownloaded(String path, String device) {
    return 'Updated $path from $device';
  }

  @override
  String syncLogDownloadedNoDevice(String path) {
    return 'Updated $path';
  }

  @override
  String syncLogMerged(String path, String device) {
    return 'Merged changes from $device into $path';
  }

  @override
  String syncLogMergedNoDevice(String path) {
    return 'Merged changes into $path';
  }

  @override
  String syncLogConflictCopy(String path, String conflictPath) {
    return '$path was changed on two devices; your version was saved as $conflictPath';
  }

  @override
  String syncLogDeletedLocal(String path, String device) {
    return 'Moved $path to the vault trash (deleted on $device)';
  }

  @override
  String syncLogDeletedLocalNoDevice(String path) {
    return 'Moved $path to the vault trash';
  }

  @override
  String syncLogDeletedRemote(String path) {
    return 'Deleted $path from sync (it stays in version history)';
  }

  @override
  String syncLogRenamedLocal(String path, String newPath) {
    return 'Renamed $path to $newPath';
  }

  @override
  String syncLogRenamedRemote(String path, String newPath, String device) {
    return 'Renamed $path to $newPath on $device';
  }

  @override
  String syncLogRenamedRemoteNoDevice(String path, String newPath) {
    return 'Renamed $path to $newPath';
  }

  @override
  String syncLogCaseConflictRenamed(String path, String newPath) {
    return 'Renamed $path to $newPath due to case conflict';
  }

  @override
  String syncLogInvalidNameRenamed(String path, String newPath) {
    return 'Renamed $path to $newPath for Windows compatibility';
  }

  @override
  String syncLogKeptEditedFileDeletedElsewhere(String path) {
    return 'Kept $path because it was edited locally after being deleted on another device';
  }

  @override
  String syncLogRestoredDeletedFileChangedElsewhere(String path) {
    return 'Restored $path because it was modified on another device';
  }

  @override
  String syncLogRepublished(String path) {
    return 'Republished $path to sync';
  }

  @override
  String syncLogHeldDeletes(int count) {
    return 'Held $count deletions for review';
  }

  @override
  String get syncLogDeviceIdRenewed => 'Device identity was renewed';

  @override
  String syncLogError(String message) {
    return 'Sync error: $message';
  }

  @override
  String get syncLogFilterAll => 'All';

  @override
  String get syncLogFilterChanges => 'Changes';

  @override
  String get syncLogFilterProblems => 'Problems';

  @override
  String get syncLogCopy => 'Copy log';

  @override
  String get syncLogEmpty => 'No sync events recorded yet.';

  @override
  String get syncLogCopied => 'Log copied to clipboard';

  @override
  String get syncSettingsAccountHeader => 'Account & remote vault';

  @override
  String get syncSettingsRemoteVaultLabel => 'Remote vault';

  @override
  String get syncSettingsDeviceNameLabel => 'Device name';

  @override
  String get syncSettingsEncryptionLabel => 'Encryption';

  @override
  String get syncSettingsEncryptionEnabled => 'Enabled (zero-knowledge)';

  @override
  String get syncSettingsEncryptionDisabled => 'Disabled (plaintext)';

  @override
  String get syncSettingsExclusionsHeader => 'Selective sync & exclusions';

  @override
  String get syncSettingsExclusionsExplain =>
      'Excluded files stay on this device and in Google Drive; they are just not synced on this device.';

  @override
  String get syncSettingsExcludedFolders => 'Excluded folders';

  @override
  String get syncSettingsAddExcludedFolder => 'Add folder';

  @override
  String get syncSettingsExcludedFileTypes => 'Excluded file extensions';

  @override
  String get syncSettingsExcludedFileTypesHint => 'e.g. mp4, zip, mov';

  @override
  String get syncSettingsMaxFileSize => 'Maximum file size';

  @override
  String get syncSettingsMaxFileSizeNoLimit => 'No limit (2 GB)';

  @override
  String get syncSettingsMobileHeader => 'Mobile network settings';

  @override
  String get syncSettingsMobileMode => 'Mobile mode (skip large media)';

  @override
  String get syncSettingsBackgroundSync => 'Background sync';

  @override
  String get syncSettingsWifiOnly => 'Sync over Wi-Fi only';

  @override
  String get syncSettingsChargingOnly => 'Sync only while charging';

  @override
  String get syncSettingsDesktopHeader => 'Desktop settings';

  @override
  String get syncSettingsKeepSyncingOnClose =>
      'Keep syncing when window is closed';

  @override
  String get syncSettingsBandwidthHeader => 'Bandwidth limits';

  @override
  String get syncSettingsUploadLimit => 'Upload limit (KiB/s, 0 = unlimited)';

  @override
  String get syncSettingsDownloadLimit =>
      'Download limit (KiB/s, 0 = unlimited)';

  @override
  String get syncSettingsSecurityHeader => 'Security & keys';

  @override
  String get syncSettingsChangePassword => 'Change vault password';

  @override
  String get syncSettingsShowRecoveryKey => 'Show new recovery key';

  @override
  String get syncSettingsDevicesLink => 'Manage devices';

  @override
  String get syncSettingsChangePasswordTitle => 'Change vault password';

  @override
  String get syncSettingsOldPassword => 'Current password or recovery key';

  @override
  String get syncSettingsNewPassword => 'New password';

  @override
  String get syncSettingsConfirmNewPassword => 'Confirm new password';

  @override
  String get syncSettingsPasswordChangedSuccess =>
      'Vault password updated successfully.';

  @override
  String get syncSettingsRecoveryKeyRegeneratedSuccess =>
      'New recovery key generated successfully.';

  @override
  String get syncDevicesTitle => 'Synced devices';

  @override
  String get syncDevicesThisDevice => 'This device';

  @override
  String syncDevicesLastSeen(String when) {
    return 'Last seen $when';
  }

  @override
  String get syncDevicesRemoved => 'Removed';

  @override
  String get syncDevicesRemove => 'Remove device';

  @override
  String syncDevicesRemoveConfirm(String name) {
    return '$name will stop syncing. Changes it makes after now are ignored. It keeps its local files. Its access to Google Drive is not revoked — to fully block it, change the vault password and remove the Google account\'s access to Tephra on that device.';
  }

  @override
  String get syncDevicesRemoveButton => 'Remove';

  @override
  String get syncDeviceRevokedTitle => 'Device removed from sync';

  @override
  String get syncDeviceRevokedReconnect =>
      'This device was removed from sync. Reconnect as a new device to resume syncing.';

  @override
  String get syncDeviceRevokedButton => 'Reconnect as new device';

  @override
  String get syncErrorAuthRevoked =>
      'Google Drive access was revoked or expired. Please reconnect.';

  @override
  String get syncErrorOffline =>
      'Device is offline. Sync will resume automatically when connected.';

  @override
  String get syncErrorDriveFull =>
      'Google Drive storage is full. Free up space to continue syncing.';

  @override
  String get syncWarningDriveAlmostFull =>
      'Google Drive storage is almost full.';

  @override
  String get syncErrorRemoteFormatNewer =>
      'The remote vault was created by a newer version of Tephra. Please update Tephra.';

  @override
  String syncErrorTampered(String device) {
    return 'Sync data from $device failed integrity verification.';
  }

  @override
  String get syncErrorVaultMissing =>
      'The remote vault folder could not be found in Google Drive.';

  @override
  String get syncErrorVaultFolderUnavailable =>
      'The local vault folder is currently inaccessible.';

  @override
  String get syncErrorKeyMissing =>
      'Encryption key is missing. Please enter your password or recovery key.';

  @override
  String get commandSyncNow => 'Sync: Sync now';

  @override
  String get commandSyncPause => 'Sync: Pause sync';

  @override
  String get commandSyncResume => 'Sync: Resume sync';

  @override
  String get commandSyncOpenLog => 'Sync: Open sync log';

  @override
  String get commandSyncOpenConflicts => 'Sync: Open conflicts';

  @override
  String get commandSyncOpenDevices => 'Sync: Manage devices';

  @override
  String get commandSyncOpenHistory => 'Sync: Open file history';

  @override
  String get commandSyncOpenDeleted => 'Sync: View recently deleted files';

  @override
  String get commandSyncBackupNow => 'Sync: Create backup now';

  @override
  String get commandSyncOpenBackups => 'Sync: Manage backups';

  @override
  String get conflictsTitle => 'Sync conflicts';

  @override
  String get conflictsEmpty =>
      'No unresolved conflicts. All files are up to date.';

  @override
  String conflictsFrom(String device, String time) {
    return 'From $device · $time';
  }

  @override
  String get conflictTheirVersion => 'Their version';

  @override
  String get conflictYourVersion => 'Your version';

  @override
  String get conflictKeepTheirs => 'Keep theirs';

  @override
  String get conflictEditMerge => 'Edit merge';

  @override
  String get conflictSaveMerge => 'Save merge';

  @override
  String get conflictResolved => 'Conflict resolved';

  @override
  String get conflictBinaryExplain =>
      'Binary files cannot be merged. Choose which version to keep.';

  @override
  String get conflictKindText => 'Text conflict';

  @override
  String get conflictKindBinary => 'Binary conflict';

  @override
  String get conflictKindCase => 'Case conflict';

  @override
  String get diffSideBySide => 'Side by side';

  @override
  String get diffInline => 'Inline';

  @override
  String get conflictOpenTheirFile => 'Open their version';

  @override
  String get conflictOpenYourFile => 'Open your version';

  @override
  String historyTitle(String name) {
    return 'Version history: $name';
  }

  @override
  String get historyCurrent => 'Current';

  @override
  String get historyLocalSnapshot => 'Local snapshot';

  @override
  String historyFromDevice(String device) {
    return '$device';
  }

  @override
  String get historyUnavailable => 'No longer available';

  @override
  String get historyRestore => 'Restore this version';

  @override
  String historyRestoreConfirm(String time) {
    return 'Restore version from $time? The current version will be saved in history.';
  }

  @override
  String get historyRestored => 'Version restored';

  @override
  String get historyCopy => 'Copy text';

  @override
  String get historyCopied => 'Version copied to clipboard';

  @override
  String get historySaveCopyAs => 'Save a copy as…';

  @override
  String get historyEmpty => 'No version history available for this file.';

  @override
  String get deletedTitle => 'Recently deleted';

  @override
  String get deletedEmpty => 'No recently deleted files.';

  @override
  String deletedBy(String device, String time) {
    return 'Deleted by $device • $time';
  }

  @override
  String get deletedRestore => 'Restore';

  @override
  String deletedRestoredAs(String path) {
    return 'Restored as $path';
  }

  @override
  String get deletedOpenHistory => 'History';

  @override
  String get backupsTitle => 'Vault Backups';

  @override
  String get backupsSchedule => 'Backup Schedule';

  @override
  String get backupsScheduleOff => 'Off';

  @override
  String get backupsScheduleHourly => 'Hourly';

  @override
  String get backupsScheduleDaily => 'Daily (03:00)';

  @override
  String get backupsScheduleWeekly => 'Weekly';

  @override
  String get backupsRetentionHourly => 'Keep hourly backups for (hours)';

  @override
  String get backupsRetentionDaily => 'Keep daily backups for (days)';

  @override
  String get backupsRetentionMonthly => 'Keep monthly backups for (months)';

  @override
  String get backupsBackUpNow => 'Back up now';

  @override
  String backupsRunning(int done, int total) {
    return 'Backing up... $done/$total files';
  }

  @override
  String backupsEntry(String date, String device, int files, String size) {
    return '$date · $device · $files files · $size';
  }

  @override
  String get backupsEmpty => 'No backups created yet';

  @override
  String backupsLastVerification(String date, int ok, int failed) {
    return 'Last verified on $date: $ok ok, $failed failed';
  }

  @override
  String get backupsRestore => 'Restore...';

  @override
  String get backupsOnlyModeCard => 'Back up only';

  @override
  String get backupsOnlyModeExplain =>
      'Create encrypted snapshots on Google Drive from this device without real-time multi-device sync.';

  @override
  String get backupsMobileModeNote =>
      'Mobile-mode file exclusions apply to backups taken from this device.';

  @override
  String get gcRunning => 'Garbage collection in progress...';

  @override
  String gcDone(int count, String bytes) {
    return 'Garbage collection complete: $count blobs removed ($bytes reclaimed)';
  }

  @override
  String backupVerificationFailed(int count) {
    return 'Backup verification failed: $count damaged blobs detected';
  }

  @override
  String get backupsVerifyNow => 'Verify now';

  @override
  String get restoreTitle => 'Restore backup';

  @override
  String get restoreChooseFiles => 'Choose files to restore';

  @override
  String get restoreSelectAll => 'Select all';

  @override
  String get restoreTargetVault => 'Restore into current vault';

  @override
  String get restoreTargetNewFolder => 'Restore into a new folder';

  @override
  String get restoreNewFolderMustBeEmpty =>
      'Target folder must be empty or not exist';

  @override
  String restoreConfirm(int count) {
    return 'Restore $count selected files?';
  }

  @override
  String restoreRunning(int done, int total) {
    return 'Restoring files: $done / $total';
  }

  @override
  String restoreReport(int restored, int skipped, int renamed, int failed) {
    return 'Restore complete: $restored restored, $skipped skipped, $renamed renamed for collision, $failed failed';
  }

  @override
  String get restoreOpenAsVault => 'Open as vault';
}
