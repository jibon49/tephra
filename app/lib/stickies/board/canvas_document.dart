// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';

/// A JSON Canvas 1.0 document preserving unknown top-level and node keys.
final class CanvasDocument {
  CanvasDocument({
    required List<CanvasNode> nodes,
    required List<Map<String, Object?>> edges,
    Map<String, Object?>? extra,
  }) : nodes = List.unmodifiable(nodes),
       edges = List.unmodifiable(
         edges.map((e) => Map<String, Object?>.unmodifiable(e)),
       ),
       extra = Map.unmodifiable(extra ?? const {});

  /// Node elements contained in the canvas.
  final List<CanvasNode> nodes;

  /// Edges connecting nodes, preserved as raw JSON maps.
  final List<Map<String, Object?>> edges;

  /// Top-level unknown keys preserved across round-trips.
  final Map<String, Object?> extra;

  /// Parses a JSON Canvas string. Throws [ParseException] on invalid JSON or
  /// non-object root.
  static CanvasDocument parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (e) {
      throw ParseException('Invalid JSON Canvas document: $e');
    }

    if (decoded is! Map) {
      throw const ParseException('JSON Canvas root must be an object');
    }

    final root = Map<String, Object?>.from(decoded);

    final rawNodes = root.remove('nodes');
    final rawEdges = root.remove('edges');

    final nodes = <CanvasNode>[];
    if (rawNodes is List) {
      for (final item in rawNodes) {
        if (item is Map) {
          nodes.add(CanvasNode.fromJson(Map<String, Object?>.from(item)));
        }
      }
    }

    final edges = <Map<String, Object?>>[];
    if (rawEdges is List) {
      for (final item in rawEdges) {
        if (item is Map) {
          edges.add(Map<String, Object?>.from(item));
        }
      }
    }

    return CanvasDocument(nodes: nodes, edges: edges, extra: root);
  }

  /// Encodes this canvas as a formatted JSON Canvas 1.0 string with 2-space
  /// indentation and a trailing newline.
  String encode() {
    final map = <String, Object?>{
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges,
    };

    for (final entry in extra.entries) {
      if (!map.containsKey(entry.key)) {
        map[entry.key] = entry.value;
      }
    }

    return '${const JsonEncoder.withIndent('  ').convert(map)}\n';
  }

  CanvasDocument copyWith({
    List<CanvasNode>? nodes,
    List<Map<String, Object?>>? edges,
    Map<String, Object?>? extra,
  }) {
    return CanvasDocument(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      extra: extra ?? this.extra,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CanvasDocument) return false;
    if (nodes.length != other.nodes.length) return false;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i] != other.nodes[i]) return false;
    }
    if (edges.length != other.edges.length) return false;
    for (var i = 0; i < edges.length; i++) {
      if (!_deepEquals(edges[i], other.edges[i])) return false;
    }
    return _deepEquals(extra, other.extra);
  }

  @override
  int get hashCode {
    return Object.hash(Object.hashAll(nodes), edges.length, extra.length);
  }
}

/// A node on the canvas (text, file, link, or group) preserving unknown keys.
final class CanvasNode {
  CanvasNode({
    required this.id,
    required this.type,
    required int x,
    required int y,
    required int width,
    required int height,
    this.color,
    this.file,
    this.text,
    this.url,
    Map<String, Object?>? extra,
  }) : x = x.round(),
       y = y.round(),
       width = width.round(),
       height = height.round(),
       extra = Map.unmodifiable(extra ?? const {});

  final String id;
  final String type; // 'text' | 'file' | 'link' | 'group'
  final int x;
  final int y;
  final int width;
  final int height;
  final String? color;
  final String? file;
  final String? text;
  final String? url;
  final Map<String, Object?> extra;

  static CanvasNode fromJson(Map<String, Object?> json) {
    final map = Map<String, Object?>.from(json);

    final id = map.remove('id')?.toString() ?? '';
    final type = map.remove('type')?.toString() ?? 'text';

    final file = map.remove('file')?.toString();
    final text = map.remove('text')?.toString();
    final url = map.remove('url')?.toString();

    final x = (map.remove('x') as num?)?.round() ?? 0;
    final y = (map.remove('y') as num?)?.round() ?? 0;
    final width = (map.remove('width') as num?)?.round() ?? 260;
    final height = (map.remove('height') as num?)?.round() ?? 220;

    final color = map.remove('color')?.toString();

    return CanvasNode(
      id: id,
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      color: color,
      file: file,
      text: text,
      url: url,
      extra: map,
    );
  }

  Map<String, Object?> toJson() {
    final map = <String, Object?>{'id': id, 'type': type};

    if (file != null) map['file'] = file;
    if (text != null) map['text'] = text;
    if (url != null) map['url'] = url;

    map['x'] = x;
    map['y'] = y;
    map['width'] = width;
    map['height'] = height;

    if (color != null) map['color'] = color;

    for (final entry in extra.entries) {
      if (!map.containsKey(entry.key)) {
        map[entry.key] = entry.value;
      }
    }

    return map;
  }

  CanvasNode copyWith({
    String? id,
    String? type,
    int? x,
    int? y,
    int? width,
    int? height,
    String? color,
    bool clearColor = false,
    String? file,
    String? text,
    String? url,
    Map<String, Object?>? extra,
  }) {
    return CanvasNode(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      color: clearColor ? null : (color ?? this.color),
      file: file ?? this.file,
      text: text ?? this.text,
      url: url ?? this.url,
      extra: extra ?? this.extra,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CanvasNode) return false;
    return id == other.id &&
        type == other.type &&
        x == other.x &&
        y == other.y &&
        width == other.width &&
        height == other.height &&
        color == other.color &&
        file == other.file &&
        text == other.text &&
        url == other.url &&
        _deepEquals(extra, other.extra);
  }

  @override
  int get hashCode {
    return Object.hash(id, type, x, y, width, height, color, file, text, url);
  }
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
