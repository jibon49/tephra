// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/board/canvas_document.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('CanvasDocument', () {
    test('round trip keeps unknown keys', () {
      const json = '''{
  "nodes": [
    {
      "id": "node-1",
      "type": "text",
      "text": "Hello world",
      "x": 100,
      "y": 200,
      "width": 260,
      "height": 220,
      "styleAttributes": {
        "x": 1
      }
    }
  ],
  "edges": [],
  "metadata": {
    "version": 1,
    "customAuthor": "Tephra"
  }
}
''';

      final doc = CanvasDocument.parse(json);
      expect(doc.nodes, hasLength(1));
      expect(doc.nodes.first.extra['styleAttributes'], {'x': 1});
      expect(doc.extra['metadata'], {'version': 1, 'customAuthor': 'Tephra'});

      final encoded = doc.encode();
      final roundTrip = CanvasDocument.parse(encoded);

      expect(roundTrip, equals(doc));
      expect(roundTrip.nodes.first.extra['styleAttributes'], {'x': 1});
      expect(roundTrip.extra['metadata'], {
        'version': 1,
        'customAuthor': 'Tephra',
      });
    });

    test('parse Obsidian sample', () {
      const sample = '''{
  "nodes": [
    {
      "id": "text-node-1",
      "type": "text",
      "text": "Welcome to Obsidian Canvas",
      "x": 0,
      "y": 0,
      "width": 250,
      "height": 140,
      "color": "3"
    },
    {
      "id": "file-node-1",
      "type": "file",
      "file": "Notes/Project.md",
      "x": 300,
      "y": 0,
      "width": 300,
      "height": 400
    },
    {
      "id": "group-node-1",
      "type": "group",
      "label": "Ideas",
      "x": -50,
      "y": -50,
      "width": 700,
      "height": 500
    }
  ],
  "edges": [
    {
      "id": "edge-1",
      "fromNode": "text-node-1",
      "fromSide": "right",
      "toNode": "file-node-1",
      "toSide": "left"
    }
  ]
}
''';

      final doc = CanvasDocument.parse(sample);
      expect(doc.nodes, hasLength(3));
      expect(doc.edges, hasLength(1));

      final encoded = doc.encode();
      final reParsed = CanvasDocument.parse(encoded);

      expect(reParsed, equals(doc));
    });

    test('invalid json throws ParseException', () {
      expect(
        () => CanvasDocument.parse('{ invalid json '),
        throwsA(isA<ParseException>()),
      );
      expect(
        () => CanvasDocument.parse('["not", "a", "map"]'),
        throwsA(isA<ParseException>()),
      );
    });

    test('doubles are rounded', () {
      const json = '''{
  "nodes": [
    {
      "id": "n1",
      "type": "file",
      "x": 10.6,
      "y": 20.3,
      "width": 100.8,
      "height": 50.2
    }
  ],
  "edges": []
}
''';

      final doc = CanvasDocument.parse(json);
      final node = doc.nodes.first;

      expect(node.x, 11);
      expect(node.y, 20);
      expect(node.width, 101);
      expect(node.height, 50);

      final encoded = doc.encode();
      expect(encoded, contains('"x": 11'));
      expect(encoded, contains('"y": 20'));
      expect(encoded, contains('"width": 101'));
      expect(encoded, contains('"height": 50'));
    });
  });
}
