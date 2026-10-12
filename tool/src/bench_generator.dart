// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'png_writer.dart';

final class BenchOptions {
  const BenchOptions({
    this.count = 10000,
    this.seed = 42,
    required this.outDir,
    this.attachments = 200,
  });

  final int count;
  final int seed;
  final String outDir;
  final int attachments;
}

final class BenchReport {
  const BenchReport({
    required this.notes,
    required this.folders,
    required this.links,
    required this.unresolvedLinks,
    required this.attachments,
    required this.bytes,
  });

  final int notes;
  final int folders;
  final int links;
  final int unresolvedLinks;
  final int attachments;
  final int bytes;

  @override
  String toString() =>
      'BenchReport(notes: $notes, folders: $folders, links: $links, unresolvedLinks: $unresolvedLinks, attachments: $attachments, bytes: $bytes)';
}

bool checkCleanAllowed(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    return true;
  }
  final entries = dir.listSync();
  if (entries.isEmpty) {
    return true;
  }
  final marker = File(p.join(dirPath, '.tephra-bench'));
  return marker.existsSync();
}

const List<String> _banglaPool = [
  'বাংলা',
  'নোট',
  'লেখা',
  'পরীক্ষা',
  'ভাষা',
  'বই',
  'সময়',
  'কাজ',
  'দিন',
  'মানুষ',
  'শহর',
  'নদী',
  'পাহাড়',
  'আলো',
  'রাত',
  'গান',
  'খেলা',
  'স্কুল',
  'বন্ধু',
  'পরিবার',
];

const List<String> _tagPrefixes = [
  'project',
  'area',
  'status',
  'topic',
  'type',
  'client',
  'dept',
  'goal',
  'review',
  'priority',
  'context',
  'team',
];

const List<String> _tagSuffixes = ['alpha', 'beta', 'todo', 'health', 'active'];

final List<String> _tagPool = [
  for (final p in _tagPrefixes)
    for (final s in _tagSuffixes) '$p/$s',
];

const List<String> _wordPool = [
  'ability',
  'access',
  'accident',
  'account',
  'action',
  'activity',
  'actor',
  'addition',
  'address',
  'admin',
  'advance',
  'advice',
  'affair',
  'affect',
  'agency',
  'agent',
  'agreement',
  'airport',
  'alarm',
  'alcohol',
  'alert',
  'algebra',
  'algorithm',
  'alien',
  'alley',
  'alliance',
  'alligator',
  'alloy',
  'almanac',
  'alphabet',
  'altitude',
  'aluminum',
  'amateur',
  'amber',
  'ambition',
  'ambulance',
  'analysis',
  'analyst',
  'anchor',
  'ancient',
  'android',
  'animal',
  'ankle',
  'annex',
  'annual',
  'antenna',
  'antique',
  'anxiety',
  'apology',
  'apparel',
  'appeal',
  'appendix',
  'appetite',
  'applaud',
  'apple',
  'arcade',
  'arch',
  'archer',
  'archive',
  'arctic',
  'arena',
  'armor',
  'army',
  'arrow',
  'article',
  'artist',
  'artwork',
  'aspect',
  'asphalt',
  'asset',
  'assist',
  'asteroid',
  'athlete',
  'atlas',
  'atom',
  'attic',
  'audio',
  'audit',
  'author',
  'auto',
  'autumn',
  'avenue',
  'average',
  'aviation',
  'award',
  'badge',
  'baggage',
  'balance',
  'balcony',
  'ballad',
  'balloon',
  'bamboo',
  'banana',
  'banner',
  'baron',
  'barrier',
  'base',
  'battery',
  'battle',
  'beacon',
  'beauty',
  'bedroom',
  'behavior',
  'belief',
  'benefit',
  'berth',
  'bicycle',
  'biology',
  'biplane',
  'biscuit',
  'bishop',
  'bison',
  'blade',
  'blanket',
  'blast',
  'blazer',
  'blessing',
  'blizzard',
  'block',
  'blossom',
  'blueprint',
  'board',
  'boiler',
  'boldness',
  'bonfire',
  'bonus',
  'bookmark',
  'booster',
  'border',
  'botany',
  'bottle',
  'boulder',
  'boundary',
  'bracket',
  'branch',
  'brass',
  'bravery',
  'bread',
  'breeze',
  'brick',
  'bridge',
  'brief',
  'brigade',
  'broadcast',
  'bronze',
  'brother',
  'bubble',
  'bucket',
  'budget',
  'builder',
  'bullet',
  'bunker',
  'burden',
  'bureau',
  'business',
  'cabin',
  'cabinet',
  'cable',
  'cactus',
  'cadet',
  'calendar',
  'camera',
  'campaign',
  'campus',
  'canal',
  'cancer',
  'candle',
  'canyon',
  'canvas',
  'canyon',
  'capable',
  'capital',
  'captain',
  'capture',
  'caravan',
  'carbon',
  'cardinal',
  'career',
  'cargo',
  'carpet',
  'carrier',
  'carrot',
  'cascade',
  'castle',
  'catalog',
  'category',
  'cathedral',
  'cause',
  'caution',
  'cavalry',
  'ceiling',
  'celebrate',
  'cement',
  'cereal',
  'ceremony',
  'chamber',
  'champion',
  'channel',
  'chapter',
  'character',
  'charge',
  'chariot',
  'charity',
  'charter',
  'check',
  'cheese',
  'chemical',
  'cherry',
  'chestnut',
  'chicken',
  'chimney',
  'circuit',
  'citizen',
  'citrus',
  'civic',
  'civilian',
  'classic',
  'climate',
  'clinic',
  'clipper',
  'clock',
  'closet',
  'cluster',
  'coach',
  'coastal',
  'cobalt',
  'coffee',
  'cognition',
  'coin',
  'collapse',
  'colleague',
  'colony',
  'column',
  'combat',
  'comfort',
  'command',
  'commerce',
  'compact',
  'company',
  'compass',
  'complex',
  'concept',
  'concert',
  'concrete',
  'conduit',
  'conflict',
  'congress',
  'connect',
  'conquest',
  'consent',
  'console',
  'constant',
  'consul',
  'contact',
  'content',
  'context',
  'contract',
  'control',
  'convert',
  'cookie',
  'copper',
  'corridor',
  'costume',
  'cottage',
  'cotton',
  'council',
  'counter',
  'country',
  'courage',
  'course',
  'court',
  'cradle',
  'craft',
  'crater',
  'credit',
  'cricket',
  'crisis',
  'critic',
  'crystal',
  'culture',
  'cupboard',
  'curtain',
  'custom',
  'cylinder',
];

class _NoteMeta {
  _NoteMeta({
    required this.index,
    required this.title,
    required this.folder,
    required this.headings,
    required this.blockIds,
  });

  final int index;
  final String title;
  final String folder;
  final List<String> headings;
  final List<String> blockIds;
}

BenchReport generateBenchVault(BenchOptions o) {
  final rng = Random(o.seed);
  final rootDir = Directory(o.outDir);
  if (!rootDir.existsSync()) {
    rootDir.createSync(recursive: true);
  }

  // 1. Folders
  const topFolders = [
    'Projects',
    'Areas',
    'Resources',
    'Archive',
    'Journal',
    'People',
    'Meetings',
    'Ideas',
  ];
  final allFolders = <String>['']; // '' represents vault root

  void generateSubfolders(String parent, int depth) {
    if (depth >= 4) {
      return;
    }
    final maxChildren = (depth == 1) ? 6 : 4;
    final count = rng.nextInt(maxChildren);
    for (var i = 1; i <= count; i++) {
      final word = _wordPool[rng.nextInt(_wordPool.length)];
      final capWord = word[0].toUpperCase() + word.substring(1);
      final subName = '$capWord $i';
      final path = parent.isEmpty ? subName : '$parent/$subName';
      allFolders.add(path);
      generateSubfolders(path, depth + 1);
    }
  }

  for (final top in topFolders) {
    allFolders.add(top);
    generateSubfolders(top, 2);
  }

  final nonRootFolders = allFolders.where((f) => f.isNotEmpty).toList();

  // Create physical folder directories
  for (final f in nonRootFolders) {
    Directory(p.join(o.outDir, f)).createSync(recursive: true);
  }
  final attachDir = Directory(p.join(o.outDir, 'Attachments'));
  attachDir.createSync(recursive: true);

  // 2. Names (pass 1)
  final notesMeta = <_NoteMeta>[];
  final usedTitles = <String>{};

  for (var k = 0; k < o.count; k++) {
    // 2-4 title-cased words
    final wordCount = 2 + rng.nextInt(3);
    final words = <String>[];
    for (var w = 0; w < wordCount; w++) {
      final word = _wordPool[rng.nextInt(_wordPool.length)];
      words.add(word[0].toUpperCase() + word.substring(1));
    }
    var title = words.join(' ');
    final titleLower = title.toLowerCase();

    if (usedTitles.contains(titleLower)) {
      title = '$title $k';
    } else {
      usedTitles.add(titleLower);
    }

    // 2% reuse title of earlier note in different folder
    String folder;
    if (k > 0 && rng.nextDouble() < 0.02) {
      final earlier = notesMeta[rng.nextInt(k)];
      title = earlier.title;
      // place in a different folder
      final otherFolders = nonRootFolders
          .where((f) => f != earlier.folder)
          .toList();
      folder = otherFolders.isNotEmpty
          ? otherFolders[rng.nextInt(otherFolders.length)]
          : (earlier.folder.isEmpty ? 'Projects' : '');
    } else {
      if (rng.nextDouble() < 0.20 || nonRootFolders.isEmpty) {
        folder = '';
      } else {
        folder = nonRootFolders[rng.nextInt(nonRootFolders.length)];
      }
    }

    final headingCount = 1 + rng.nextInt(5);
    final headings = <String>[];
    for (var h = 0; h < headingCount; h++) {
      final hWords = [
        for (var i = 0; i < 1 + rng.nextInt(3); i++)
          _wordPool[rng.nextInt(_wordPool.length)],
      ];
      headings.add(
        hWords.map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
      );
    }

    final blockIds = <String>[];
    if (rng.nextDouble() < 0.15) {
      final bCount = 1 + rng.nextInt(3);
      for (var j = 0; j < bCount; j++) {
        blockIds.add('b${k}x$j');
      }
    }

    notesMeta.add(
      _NoteMeta(
        index: k,
        title: title,
        folder: folder,
        headings: headings,
        blockIds: blockIds,
      ),
    );
  }

  // 3. Size classes
  final sizeClasses = <int>[];
  for (var k = 0; k < o.count; k++) {
    final r = rng.nextDouble();
    int lines;
    if (r < 0.40) {
      lines = 3 + rng.nextInt(6); // 3..8
    } else if (r < 0.85) {
      lines = 10 + rng.nextInt(51); // 10..60
    } else if (r < 0.99) {
      lines = 60 + rng.nextInt(341); // 60..400
    } else {
      lines = 1000 + rng.nextInt(1001); // 1000..2000
    }
    sizeClasses.add(lines);
  }

  // 4. Content (pass 2)
  var totalLinks = 0;
  var totalUnresolved = 0;
  var totalBytes = 0;

  for (var k = 0; k < o.count; k++) {
    final meta = notesMeta[k];
    final linesTarget = sizeClasses[k];
    final buffer = StringBuffer();

    // Frontmatter 50%
    if (rng.nextDouble() < 0.50) {
      buffer.writeln('---');
      final tagCount = 1 + rng.nextInt(3);
      buffer.writeln('tags:');
      for (var t = 0; t < tagCount; t++) {
        buffer.writeln('  - ${_tagPool[rng.nextInt(_tagPool.length)]}');
      }
      if (rng.nextDouble() < 0.20) {
        final aliasCount = 1 + rng.nextInt(2);
        buffer.writeln('aliases:');
        for (var a = 0; a < aliasCount; a++) {
          final w = _wordPool[rng.nextInt(_wordPool.length)];
          buffer.writeln('  - ${w[0].toUpperCase() + w.substring(1)} Alias');
        }
      }
      final mm = (1 + rng.nextInt(12)).toString().padLeft(2, '0');
      final dd = (1 + rng.nextInt(28)).toString().padLeft(2, '0');
      buffer.writeln('created: 2026-$mm-$dd');
      buffer.writeln('status: ${['draft', 'active', 'done'][rng.nextInt(3)]}');
      buffer.writeln('---');
    }

    // Wikilinks to insert
    final noteLinkCount = rng.nextInt(11);
    final linkQueue = <String>[];
    for (var l = 0; l < noteLinkCount; l++) {
      totalLinks++;
      final lr = rng.nextDouble();
      final target = notesMeta[rng.nextInt(o.count)];
      if (lr < 0.70) {
        linkQueue.add('[[${target.title}]]');
      } else if (lr < 0.80) {
        final aliasWord = _wordPool[rng.nextInt(_wordPool.length)];
        linkQueue.add('[[${target.title}|$aliasWord]]');
      } else if (lr < 0.90) {
        final h = target.headings[rng.nextInt(target.headings.length)];
        linkQueue.add('[[${target.title}#$h]]');
      } else if (lr < 0.95) {
        if (target.blockIds.isNotEmpty) {
          final b = target.blockIds[rng.nextInt(target.blockIds.length)];
          linkQueue.add('[[${target.title}#^$b]]');
        } else {
          linkQueue.add('[[${target.title}]]');
        }
      } else if (lr < 0.98) {
        totalUnresolved++;
        linkQueue.add('[[Missing Note ${rng.nextInt(1000)}]]');
      } else {
        final imgIdx = (rng.nextInt(o.attachments) + 1).toString().padLeft(
          3,
          '0',
        );
        linkQueue.add('![[image-$imgIdx.png]]');
      }
    }

    // Tags to insert (0..4 inline tags)
    final noteTagCount = rng.nextInt(5);
    final tagQueue = <String>[];
    for (var t = 0; t < noteTagCount; t++) {
      tagQueue.add('#${_tagPool[rng.nextInt(_tagPool.length)]}');
    }

    // Body content
    var currentLines = 0;
    var headingIdx = 0;
    var blockIdIdx = 0;

    while (currentLines < linesTarget) {
      if (headingIdx < meta.headings.length) {
        buffer.writeln('## ${meta.headings[headingIdx++]}');
        currentLines++;
        if (currentLines >= linesTarget) break;
      }

      // 15% lists
      if (rng.nextDouble() < 0.15) {
        final itemCount = 2 + rng.nextInt(4);
        for (var i = 0; i < itemCount; i++) {
          final w = _wordPool[rng.nextInt(_wordPool.length)];
          buffer.writeln('- Item $w');
          currentLines++;
        }
      } else if (rng.nextDouble() < 0.10) {
        // tasks 10%
        final done = rng.nextBool() ? 'x' : ' ';
        final w = _wordPool[rng.nextInt(_wordPool.length)];
        buffer.writeln('- [$done] Task $w');
        currentLines++;
      } else if (rng.nextDouble() < 0.05) {
        // fenced code 5%
        buffer.writeln('```dart');
        buffer.writeln('void fn$currentLines() {}');
        buffer.writeln('```');
        currentLines += 3;
      } else {
        // Paragraph of 1-4 sentences
        final sentenceCount = 1 + rng.nextInt(4);
        final sentenceList = <String>[];
        for (var s = 0; s < sentenceCount; s++) {
          final wordCount = 6 + rng.nextInt(13);
          final words = <String>[];
          for (var w = 0; w < wordCount; w++) {
            if (rng.nextDouble() < 0.08) {
              words.add(_banglaPool[rng.nextInt(_banglaPool.length)]);
            } else {
              words.add(_wordPool[rng.nextInt(_wordPool.length)]);
            }
          }
          if (linkQueue.isNotEmpty && rng.nextDouble() < 0.5) {
            words.add(linkQueue.removeLast());
          }
          if (tagQueue.isNotEmpty && rng.nextDouble() < 0.4) {
            words.add(tagQueue.removeLast());
          }
          final sentence = words.join(' ');
          sentenceList.add(
            '${sentence[0].toUpperCase()}${sentence.substring(1)}.',
          );
        }

        var para = sentenceList.join(' ');
        if (blockIdIdx < meta.blockIds.length && rng.nextDouble() < 0.4) {
          para = '$para ^${meta.blockIds[blockIdIdx++]}';
        }
        buffer.writeln(para);
        buffer.writeln(); // blank line
        currentLines += 2;
      }
    }

    // Flush any remaining links or tags into a final line
    if (linkQueue.isNotEmpty) {
      buffer.writeln('Links: ${linkQueue.join(' ')}');
    }
    if (tagQueue.isNotEmpty) {
      buffer.writeln('Tags: ${tagQueue.join(' ')}');
    }

    final noteBytes = utf8.encode(buffer.toString());
    final notePath = meta.folder.isEmpty
        ? p.join(o.outDir, '${meta.title}.md')
        : p.join(o.outDir, meta.folder, '${meta.title}.md');

    File(notePath).writeAsBytesSync(noteBytes, flush: true);
    totalBytes += noteBytes.length;
  }

  // 5. Attachments
  for (var a = 1; a <= o.attachments; a++) {
    final name = 'image-${a.toString().padLeft(3, '0')}.png';
    final r = rng.nextInt(256);
    final g = rng.nextInt(256);
    final b = rng.nextInt(256);
    final png = encodePng(1, 1, [r, g, b]);
    final filePath = p.join(o.outDir, 'Attachments', name);
    File(filePath).writeAsBytesSync(png, flush: true);
    totalBytes += png.length;
  }

  // 6. Marker
  final marker = File(p.join(o.outDir, '.tephra-bench'));
  final markerBytes = utf8.encode('seed=${o.seed} count=${o.count}\n');
  marker.writeAsBytesSync(markerBytes, flush: true);
  totalBytes += markerBytes.length;

  return BenchReport(
    notes: o.count,
    folders: nonRootFolders.length + 1, // + Attachments
    links: totalLinks,
    unresolvedLinks: totalUnresolved,
    attachments: o.attachments,
    bytes: totalBytes,
  );
}
