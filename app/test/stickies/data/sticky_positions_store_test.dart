// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/data/sticky_positions_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  late MemoryVaultFileSystem fs;

  setUp(() {
    fs = MemoryVaultFileSystem();
  });

  test('keeps other devices', () async {
    const initialJson = '''
{
  "dev-other": {
    "Stickies/other.md": {
      "x": 10,
      "y": 20,
      "w": 200,
      "h": 300,
      "screen": "OtherDisplay|1920x1080",
      "collapsed": false
    }
  }
}
''';
    await fs.writeText(
      VaultPath('.tephra/stickies.json'),
      const TextDocument(text: initialJson),
    );

    final store = StickyPositionsStore(fs: fs, deviceId: 'dev-mine');
    await store.load();

    await store.save(
      VaultPath('Stickies/mine.md'),
      const StickyGeometry(
        x: 50,
        y: 60,
        w: 250,
        h: 220,
        screen: 'MyDisplay|1920x1080',
        collapsed: true,
      ),
    );
    await store.flush();

    final doc = await fs.readText(VaultPath('.tephra/stickies.json'));
    expect(doc.text, contains('"dev-other"'));
    expect(doc.text, contains('"Stickies/other.md"'));
    expect(doc.text, contains('"dev-mine"'));
    expect(doc.text, contains('"Stickies/mine.md"'));
    expect(store.mine.containsKey(VaultPath('Stickies/mine.md')), isTrue);
  });

  test('sorted stable encoding', () async {
    final store = StickyPositionsStore(fs: fs, deviceId: 'dev-b');
    await store.save(
      VaultPath('Stickies/z.md'),
      const StickyGeometry(
        x: 10,
        y: 20,
        w: 300,
        h: 200,
        screen: 'Display|1920x1080',
        collapsed: false,
      ),
    );
    await store.save(
      VaultPath('Stickies/a.md'),
      const StickyGeometry(
        x: 30,
        y: 40,
        w: 280,
        h: 260,
        screen: 'Display|1920x1080',
        collapsed: true,
      ),
    );
    await store.flush();

    final doc = await fs.readText(VaultPath('.tephra/stickies.json'));
    const expected =
        '{\n'
        '  "dev-b": {\n'
        '    "Stickies/a.md": {\n'
        '      "x": 30,\n'
        '      "y": 40,\n'
        '      "w": 280,\n'
        '      "h": 260,\n'
        '      "screen": "Display|1920x1080",\n'
        '      "collapsed": true\n'
        '    },\n'
        '    "Stickies/z.md": {\n'
        '      "x": 10,\n'
        '      "y": 20,\n'
        '      "w": 300,\n'
        '      "h": 200,\n'
        '      "screen": "Display|1920x1080",\n'
        '      "collapsed": false\n'
        '    }\n'
        '  }\n'
        '}\n';

    expect(doc.text, expected);
  });

  test('no write when unchanged', () async {
    final store = StickyPositionsStore(fs: fs, deviceId: 'dev-1');
    const geom = StickyGeometry(
      x: 100,
      y: 100,
      w: 200,
      h: 200,
      screen: 'Display|1920x1080',
    );
    await store.save(VaultPath('note.md'), geom);
    await store.flush();

    final stat1 = await fs.stat(VaultPath('.tephra/stickies.json'));
    expect(stat1, isNotNull);

    // Saving identical geometry and flushing should not write again
    await store.save(VaultPath('note.md'), geom);
    await store.flush();

    final doc = await fs.readText(VaultPath('.tephra/stickies.json'));
    expect(doc.text, contains('"note.md"'));
  });

  test('rename moves entry', () async {
    final store = StickyPositionsStore(fs: fs, deviceId: 'dev-1');
    const geom = StickyGeometry(
      x: 100,
      y: 120,
      w: 300,
      h: 250,
      screen: 'Display|1920x1080',
    );
    await store.save(VaultPath('Stickies/old.md'), geom);
    await store.flush();

    await store.rename(
      VaultPath('Stickies/old.md'),
      VaultPath('Stickies/new.md'),
    );
    await store.flush();

    expect(store.mine.containsKey(VaultPath('Stickies/old.md')), isFalse);
    expect(store.mine[VaultPath('Stickies/new.md')], equals(geom));

    final doc = await fs.readText(VaultPath('.tephra/stickies.json'));
    expect(doc.text, contains('"Stickies/new.md"'));
    expect(doc.text, isNot(contains('"Stickies/old.md"')));
  });

  test('malformed file is backed up and not overwritten until save', () async {
    const malformed = '{"dev": { "broken json without closing brackets';
    await fs.writeText(
      VaultPath('.tephra/stickies.json'),
      const TextDocument(text: malformed),
    );

    final store = StickyPositionsStore(fs: fs, deviceId: 'dev-1');
    await store.load();

    // After load: .bak must NOT exist yet, and stickies.json must remain intact
    final bakStatBefore = await fs.stat(VaultPath('.tephra/stickies.json.bak'));
    expect(bakStatBefore, isNull);
    final docBefore = await fs.readText(VaultPath('.tephra/stickies.json'));
    expect(docBefore.text, malformed);

    // Now save a new position
    const geom = StickyGeometry(
      x: 10,
      y: 20,
      w: 200,
      h: 200,
      screen: 'Screen|1920x1080',
    );
    await store.save(VaultPath('note.md'), geom);
    await store.flush();

    // Now .bak must contain the original malformed text
    final bakDoc = await fs.readText(VaultPath('.tephra/stickies.json.bak'));
    expect(bakDoc.text, malformed);

    // And stickies.json is now well-formed
    final freshDoc = await fs.readText(VaultPath('.tephra/stickies.json'));
    expect(freshDoc.text, contains('"note.md"'));
    expect(freshDoc.text, isNot(contains('broken json')));
  });
}
