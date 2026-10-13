// © 2026 Tephra. All rights reserved.

const Map<String, String> _commandIdMap = {
  'editor:toggle-bold': 'editor.toggle-bold',
  'editor:toggle-italics': 'editor.toggle-italic',
  'editor:toggle-strikethrough': 'editor.toggle-strikethrough',
  'editor:toggle-highlight': 'editor.toggle-highlight',
  'editor:toggle-code': 'editor.toggle-code',
  'editor:insert-link': 'editor.insert-link',
  'editor:toggle-bullet-list': 'editor.toggle-bullet-list',
  'editor:toggle-numbered-list': 'editor.toggle-numbered-list',
  'editor:toggle-checklist-status': 'editor.toggle-task',
  'editor:toggle-blockquote': 'editor.toggle-quote',
  'editor:swap-line-up': 'editor.move-line-up',
  'editor:swap-line-down': 'editor.move-line-down',
  'editor:indent-list': 'editor.indent-list',
  'editor:unindent-list': 'editor.outdent-list',
  'editor:open-search': 'editor.find',
  'editor:open-search-replace': 'editor.replace',
  'editor:save-file': 'note.save',
  'markdown:toggle-preview': 'editor.toggle-reading-view',
  'switcher:open': 'app.open-quick-switcher',
  'command-palette:open': 'app.open-command-palette',
  'file-explorer:new-file': 'note.create-note',
  'workspace:close': 'workspace.close-tab',
  'workspace:next-tab': 'workspace.next-tab',
  'workspace:previous-tab': 'workspace.previous-tab',
  'app:go-back': 'workspace.go-back',
  'app:go-forward': 'workspace.go-forward',
  'workspace:split-vertical': 'workspace.split-right',
  'workspace:split-horizontal': 'workspace.split-down',
  'app:open-settings': 'app.open-settings',
};

const Set<String> _namedKeys = {
  'Enter',
  'Tab',
  'Escape',
  'Backspace',
  'Delete',
  'Home',
  'End',
  'PageUp',
  'PageDown',
  'F1',
  'F2',
  'F3',
  'F4',
  'F5',
  'F6',
  'F7',
  'F8',
  'F9',
  'F10',
  'F11',
  'F12',
};

String? _normalizeKey(String key) {
  if (key.length == 1) {
    if (key == ' ') return 'Space';
    return key.toUpperCase();
  }
  switch (key) {
    case 'ArrowUp':
      return 'Up';
    case 'ArrowDown':
      return 'Down';
    case 'ArrowLeft':
      return 'Left';
    case 'ArrowRight':
      return 'Right';
    default:
      if (_namedKeys.contains(key)) return key;
      return null;
  }
}

String? _convertShortcut(Map<String, Object?> entry) {
  final rawKey = entry['key'];
  if (rawKey is! String) return null;
  final key = _normalizeKey(rawKey);
  if (key == null) return null;

  final rawMods = entry['modifiers'];
  final mods = <String>{};
  if (rawMods is List) {
    for (final m in rawMods) {
      if (m is String) {
        if (m == 'Mod' || m == 'Ctrl') {
          mods.add('Ctrl');
        } else if (m == 'Alt') {
          mods.add('Alt');
        } else if (m == 'Shift') {
          mods.add('Shift');
        } else if (m == 'Meta') {
          mods.add('Meta');
        }
      }
    }
  }

  final parts = <String>[];
  if (mods.contains('Ctrl')) parts.add('Ctrl');
  if (mods.contains('Alt')) parts.add('Alt');
  if (mods.contains('Shift')) parts.add('Shift');
  if (mods.contains('Meta')) parts.add('Meta');
  parts.add(key);

  return parts.join('+');
}

/// Converts Obsidian `hotkeys.json` structure to Tephra shortcut map.
Map<String, List<String>> convertObsidianHotkeys(
  Map<String, Object?> obsidianJson,
) {
  final result = <String, List<String>>{};

  for (final entry in obsidianJson.entries) {
    final obsidianCmd = entry.key;
    final tephraCmd = _commandIdMap[obsidianCmd];
    if (tephraCmd == null) continue;

    final rawList = entry.value;
    if (rawList is List) {
      if (rawList.isEmpty) {
        result[tephraCmd] = [];
        continue;
      }

      final shortcuts = <String>[];
      for (final item in rawList) {
        if (item is Map) {
          final s = _convertShortcut(item.cast<String, Object?>());
          if (s != null) shortcuts.add(s);
        }
      }
      result[tephraCmd] = shortcuts;
    }
  }

  return result;
}
