// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:logging/logging.dart';

final _log = Logger('sticky_protocol');

/// The current version of the sticky window protocol.
const int kStickyProtocolVersion = 1;

/// Arguments passed to newly created sticky windows via [WindowConfiguration.arguments].
final class StickyWindowArgs {
  const StickyWindowArgs({
    required this.mainWindowId,
    required this.path,
    this.protocolVersion = kStickyProtocolVersion,
  });

  final String mainWindowId;
  final String path;
  final int protocolVersion;

  /// Serializes arguments to a JSON string.
  String encode() {
    return jsonEncode({
      'kind': 'tephra-sticky',
      'v': protocolVersion,
      'main': mainWindowId,
      'path': path,
    });
  }

  /// Decodes arguments from a JSON string. Returns null if invalid or not a sticky window.
  static StickyWindowArgs? tryDecode(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?> &&
          decoded is! Map<dynamic, dynamic>) {
        return null;
      }
      final map = (decoded as Map).cast<String, Object?>();
      if (map['kind'] != 'tephra-sticky') return null;

      final v = map['v'];
      final main = map['main'];
      final path = map['path'];

      if (v is! int || main is! String || path is! String) {
        return null;
      }

      return StickyWindowArgs(
        mainWindowId: main,
        path: path,
        protocolVersion: v,
      );
    } catch (e, st) {
      _log.fine('Failed to decode StickyWindowArgs: $raw', e, st);
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickyWindowArgs &&
          runtimeType == other.runtimeType &&
          mainWindowId == other.mainWindowId &&
          path == other.path &&
          protocolVersion == other.protocolVersion;

  @override
  int get hashCode =>
      mainWindowId.hashCode ^ path.hashCode ^ protocolVersion.hashCode;

  @override
  String toString() =>
      'StickyWindowArgs(main: $mainWindowId, path: $path, v: $protocolVersion)';
}

/// Abstract base sealed class for all messages exchanged between the main window and sticky windows.
sealed class StickyMessage {
  const StickyMessage();

  /// Serializes this message to a JSON map including `"v": 1` and `"type": "<type>"`.
  Map<String, Object?> toJson();

  /// Deserializes a message from a JSON map. Returns null if invalid, unknown type, or wrong version.
  static StickyMessage? fromJson(Map<String, Object?> json) {
    final v = json['v'];
    if (v != kStickyProtocolVersion) {
      _log.fine('Ignored message with invalid protocol version: $v');
      return null;
    }

    final type = json['type'];
    if (type is! String) return null;

    try {
      switch (type) {
        case 'ready':
          final path = json['path'];
          if (path is! String) return null;
          return ReadyMessage(path: path);

        case 'open':
          final path = json['path'];
          final text = json['text'];
          final hash = json['hash'];
          final color = json['color'];
          final pinned = json['pinned'];
          final locked = json['locked'];
          final collapsed = json['collapsed'];
          final title = json['title'];
          final focusEdit = (json['focusEdit'] as bool?) ?? false;
          final x = json['x'] as num?;
          final y = json['y'] as num?;
          final width = json['width'] as num?;
          final height = json['height'] as num?;
          if (path is! String ||
              text is! String ||
              hash is! String ||
              color is! String ||
              pinned is! bool ||
              locked is! bool ||
              collapsed is! bool ||
              title is! String) {
            return null;
          }
          return OpenMessage(
            path: path,
            text: text,
            hash: hash,
            color: color,
            pinned: pinned,
            locked: locked,
            collapsed: collapsed,
            title: title,
            focusEdit: focusEdit,
            x: x?.toDouble(),
            y: y?.toDouble(),
            width: width?.toDouble(),
            height: height?.toDouble(),
          );

        case 'update':
          final path = json['path'];
          final text = json['text'];
          final hash = json['hash'];
          final color = json['color'];
          final pinned = json['pinned'];
          final locked = json['locked'];
          final title = json['title'];
          if (path is! String ||
              text is! String ||
              hash is! String ||
              color is! String ||
              pinned is! bool ||
              locked is! bool ||
              title is! String) {
            return null;
          }
          return UpdateMessage(
            path: path,
            text: text,
            hash: hash,
            color: color,
            pinned: pinned,
            locked: locked,
            title: title,
          );

        case 'contentChanged':
          final path = json['path'];
          final text = json['text'];
          final baseHash = json['baseHash'];
          if (path is! String || text is! String || baseHash is! String) {
            return null;
          }
          return ContentChangedMessage(
            path: path,
            text: text,
            baseHash: baseHash,
          );

        case 'save':
          final path = json['path'];
          if (path is! String) return null;
          return SaveMessage(path: path);

        case 'saved':
          final path = json['path'];
          final hash = json['hash'];
          if (path is! String || hash is! String) return null;
          return SavedMessage(path: path, hash: hash);

        case 'setColor':
          final path = json['path'];
          final color = json['color'];
          if (path is! String || color is! String) return null;
          return SetColorMessage(path: path, color: color);

        case 'setPinned':
          final path = json['path'];
          final pinned = json['pinned'];
          if (path is! String || pinned is! bool) return null;
          return SetPinnedMessage(path: path, pinned: pinned);

        case 'setLocked':
          final path = json['path'];
          final locked = json['locked'];
          if (path is! String || locked is! bool) return null;
          return SetLockedMessage(path: path, locked: locked);

        case 'positionChanged':
          final path = json['path'];
          final x = json['x'];
          final y = json['y'];
          final w = json['w'];
          final h = json['h'];
          final screen = json['screen'];
          final collapsed = json['collapsed'];
          if (path is! String ||
              x is! num ||
              y is! num ||
              w is! num ||
              h is! num ||
              screen is! String ||
              collapsed is! bool) {
            return null;
          }
          return PositionChangedMessage(
            path: path,
            x: x.toInt(),
            y: y.toInt(),
            w: w.toInt(),
            h: h.toInt(),
            screen: screen,
            collapsed: collapsed,
          );

        case 'close':
          final path = json['path'];
          if (path is! String) return null;
          return CloseMessage(path: path);

        case 'closeRequest':
          final path = json['path'];
          final reason = json['reason'];
          if (path is! String || reason is! String) return null;
          return CloseRequestMessage(path: path, reason: reason);

        case 'openInMain':
          final path = json['path'];
          if (path is! String) return null;
          return OpenInMainMessage(path: path);

        case 'newSticky':
          return const NewStickyMessage();

        default:
          _log.fine('Unknown message type: $type');
          return null;
      }
    } catch (e, st) {
      _log.fine('Error parsing message of type $type: $json', e, st);
      return null;
    }
  }
}

/// Message sent from sticky window to main window when the sticky engine is ready.
final class ReadyMessage extends StickyMessage {
  const ReadyMessage({required this.path});

  final String path;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'ready',
    'path': path,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadyMessage &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode ^ 1;

  @override
  String toString() => 'ReadyMessage(path: $path)';
}

/// Message sent from main window to sticky window with full initial note state.
final class OpenMessage extends StickyMessage {
  const OpenMessage({
    required this.path,
    required this.text,
    required this.hash,
    required this.color,
    required this.pinned,
    required this.locked,
    required this.collapsed,
    required this.title,
    this.focusEdit = false,
    this.x,
    this.y,
    this.width,
    this.height,
  });

  final String path;
  final String text;
  final String hash;
  final String color;
  final bool pinned;
  final bool locked;
  final bool collapsed;
  final String title;
  final bool focusEdit;
  final double? x;
  final double? y;
  final double? width;
  final double? height;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'open',
    'path': path,
    'text': text,
    'hash': hash,
    'color': color,
    'pinned': pinned,
    'locked': locked,
    'collapsed': collapsed,
    'title': title,
    if (focusEdit) 'focusEdit': true,
    if (x != null) 'x': x,
    if (y != null) 'y': y,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          text == other.text &&
          hash == other.hash &&
          color == other.color &&
          pinned == other.pinned &&
          locked == other.locked &&
          collapsed == other.collapsed &&
          title == other.title &&
          focusEdit == other.focusEdit &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(
    path,
    text,
    hash,
    color,
    pinned,
    locked,
    collapsed,
    title,
    focusEdit,
    x,
    y,
    width,
    height,
  );

  @override
  String toString() => 'OpenMessage(path: $path, title: $title, hash: $hash)';
}

/// Message sent from main window to sticky window when note content/meta changed externally.
final class UpdateMessage extends StickyMessage {
  const UpdateMessage({
    required this.path,
    required this.text,
    required this.hash,
    required this.color,
    required this.pinned,
    required this.locked,
    required this.title,
  });

  final String path;
  final String text;
  final String hash;
  final String color;
  final bool pinned;
  final bool locked;
  final String title;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'update',
    'path': path,
    'text': text,
    'hash': hash,
    'color': color,
    'pinned': pinned,
    'locked': locked,
    'title': title,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          text == other.text &&
          hash == other.hash &&
          color == other.color &&
          pinned == other.pinned &&
          locked == other.locked &&
          title == other.title;

  @override
  int get hashCode =>
      Object.hash(path, text, hash, color, pinned, locked, title);

  @override
  String toString() => 'UpdateMessage(path: $path, title: $title, hash: $hash)';
}

/// Message sent from sticky window to main window when user edits the text.
final class ContentChangedMessage extends StickyMessage {
  const ContentChangedMessage({
    required this.path,
    required this.text,
    required this.baseHash,
  });

  final String path;
  final String text;
  final String baseHash;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'contentChanged',
    'path': path,
    'text': text,
    'baseHash': baseHash,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentChangedMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          text == other.text &&
          baseHash == other.baseHash;

  @override
  int get hashCode => Object.hash(path, text, baseHash);

  @override
  String toString() =>
      'ContentChangedMessage(path: $path, baseHash: $baseHash)';
}

/// Message sent from sticky window to main window requesting immediate save to disk.
final class SaveMessage extends StickyMessage {
  const SaveMessage({required this.path});

  final String path;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'save',
    'path': path,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveMessage &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode ^ 2;

  @override
  String toString() => 'SaveMessage(path: $path)';
}

/// Message sent from main window to sticky window confirming note is saved on disk.
final class SavedMessage extends StickyMessage {
  const SavedMessage({required this.path, required this.hash});

  final String path;
  final String hash;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'saved',
    'path': path,
    'hash': hash,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          hash == other.hash;

  @override
  int get hashCode => Object.hash(path, hash);

  @override
  String toString() => 'SavedMessage(path: $path, hash: $hash)';
}

/// Message sent from sticky window to main window to set sticky colour.
final class SetColorMessage extends StickyMessage {
  const SetColorMessage({required this.path, required this.color});

  final String path;
  final String color;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'setColor',
    'path': path,
    'color': color,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetColorMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          color == other.color;

  @override
  int get hashCode => Object.hash(path, color);

  @override
  String toString() => 'SetColorMessage(path: $path, color: $color)';
}

/// Message sent from sticky window to main window to toggle pinned status.
final class SetPinnedMessage extends StickyMessage {
  const SetPinnedMessage({required this.path, required this.pinned});

  final String path;
  final bool pinned;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'setPinned',
    'path': path,
    'pinned': pinned,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetPinnedMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          pinned == other.pinned;

  @override
  int get hashCode => Object.hash(path, pinned);

  @override
  String toString() => 'SetPinnedMessage(path: $path, pinned: $pinned)';
}

/// Message sent from sticky window to main window to toggle locked status.
final class SetLockedMessage extends StickyMessage {
  const SetLockedMessage({required this.path, required this.locked});

  final String path;
  final bool locked;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'setLocked',
    'path': path,
    'locked': locked,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetLockedMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          locked == other.locked;

  @override
  int get hashCode => Object.hash(path, locked);

  @override
  String toString() => 'SetLockedMessage(path: $path, locked: $locked)';
}

/// Message sent from sticky window to main window when its position/size changes.
final class PositionChangedMessage extends StickyMessage {
  const PositionChangedMessage({
    required this.path,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.screen,
    required this.collapsed,
  });

  final String path;
  final int x;
  final int y;
  final int w;
  final int h;
  final String screen;
  final bool collapsed;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'positionChanged',
    'path': path,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'screen': screen,
    'collapsed': collapsed,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionChangedMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          x == other.x &&
          y == other.y &&
          w == other.w &&
          h == other.h &&
          screen == other.screen &&
          collapsed == other.collapsed;

  @override
  int get hashCode => Object.hash(path, x, y, w, h, screen, collapsed);

  @override
  String toString() =>
      'PositionChangedMessage(path: $path, x: $x, y: $y, w: $w, h: $h, screen: $screen, collapsed: $collapsed)';
}

/// Message sent from sticky window to main window when window was closed by user.
final class CloseMessage extends StickyMessage {
  const CloseMessage({required this.path});

  final String path;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'close',
    'path': path,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloseMessage &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode ^ 3;

  @override
  String toString() => 'CloseMessage(path: $path)';
}

/// Message sent from main window to sticky window requesting it to close.
final class CloseRequestMessage extends StickyMessage {
  const CloseRequestMessage({required this.path, required this.reason});

  final String path;
  final String reason;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'closeRequest',
    'path': path,
    'reason': reason,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloseRequestMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(path, reason);

  @override
  String toString() => 'CloseRequestMessage(path: $path, reason: $reason)';
}

/// Message sent from sticky window to main window requesting to open note in main Tephra window.
final class OpenInMainMessage extends StickyMessage {
  const OpenInMainMessage({required this.path});

  final String path;

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'openInMain',
    'path': path,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenInMainMessage &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode ^ 4;

  @override
  String toString() => 'OpenInMainMessage(path: $path)';
}

/// Message sent from sticky window to main window requesting to create a new sticky note.
final class NewStickyMessage extends StickyMessage {
  const NewStickyMessage();

  @override
  Map<String, Object?> toJson() => {
    'v': kStickyProtocolVersion,
    'type': 'newSticky',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewStickyMessage && runtimeType == other.runtimeType;

  @override
  int get hashCode => 5;

  @override
  String toString() => 'NewStickyMessage()';
}
