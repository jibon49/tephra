// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  test('VaultIgnore ignores always-ignored segments', () {
    const ignore = VaultIgnore();
    expect(ignore.isIgnored(VaultPath('.obsidian/app.json')), isTrue);
    expect(ignore.isIgnored(VaultPath('a/.tephra/x')), isTrue);
    expect(ignore.isIgnored(VaultPath('.trash/n.md')), isTrue);
    expect(ignore.isIgnored(VaultPath('.git/config')), isTrue);
    expect(ignore.isIgnored(VaultPath('node_modules/x/y.md')), isTrue);
  });

  test('VaultIgnore handles hidden files with showHidden flag', () {
    const hiddenIgnored = VaultIgnore(showHidden: false);
    expect(hiddenIgnored.isIgnored(VaultPath('.hidden/n.md')), isTrue);

    const hiddenAllowed = VaultIgnore(showHidden: true);
    expect(hiddenAllowed.isIgnored(VaultPath('.hidden/n.md')), isFalse);
    expect(hiddenAllowed.isIgnored(VaultPath('.obsidian/x')), isTrue);
  });

  test('VaultIgnore respects excludedFolders case-insensitively', () {
    final ignore = VaultIgnore(excludedFolders: [VaultPath('Archive/Old')]);

    expect(ignore.isIgnored(VaultPath('Archive/Old/n.md')), isTrue);
    expect(ignore.isIgnored(VaultPath('archive/old/n.md')), isTrue);
    expect(ignore.isIgnored(VaultPath('Archive/Older/n.md')), isFalse);
  });

  test('VaultIgnore never ignores root and ordinary notes', () {
    const ignore = VaultIgnore();
    expect(ignore.isIgnored(VaultPath.root), isFalse);
    expect(ignore.isIgnored(VaultPath('Note.md')), isFalse);
    expect(ignore.isIgnored(VaultPath('Folder/Sub/Note.md')), isFalse);
  });
}
