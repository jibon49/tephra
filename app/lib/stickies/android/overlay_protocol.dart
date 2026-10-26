// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:logging/logging.dart';

final _log = Logger('overlay_protocol');

/// The current version of the sticky overlay protocol.
const int kOverlayProtocolVersion = 1;

/// Abstract base sealed class for all messages exchanged between the main app and the overlay bubble.
sealed class OverlayMessage {
  const OverlayMessage();

  /// Serializes this message to a JSON map including `"v": 1` and `"type": "<type>"`.
  Map<String, Object?> toJson();

  /// Deserializes a message from a JSON map or string. Returns null if invalid or wrong version.
  static OverlayMessage? fromDynamic(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      if (data.trim().isEmpty) return null;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return fromJson(decoded.cast<String, Object?>());
        }
      } catch (e, st) {
        _log.fine('Failed to parse overlay message string: $data', e, st);
        return null;
      }
    } else if (data is Map) {
      return fromJson(data.cast<String, Object?>());
    }
    return null;
  }

  /// Deserializes a message from a JSON map. Returns null if invalid, unknown type, or wrong version.
  static OverlayMessage? fromJson(Map<String, Object?> json) {
    final v = json['v'];
    if (v != kOverlayProtocolVersion) {
      _log.fine('Ignored overlay message with invalid protocol version: $v');
      return null;
    }

    final type = json['type'];
    if (type is! String) return null;

    switch (type) {
      case 'open':
        return OverlayOpenMessage.fromJson(json);
      case 'update':
        return OverlayUpdateMessage.fromJson(json);
      case 'contentChanged':
        return OverlayContentChangedMessage.fromJson(json);
      case 'ack':
        return OverlayAckMessage.fromJson(json);
      case 'close':
        return OverlayCloseMessage.fromJson(json);
      case 'ping':
        return const OverlayPingMessage();
      case 'pong':
        return const OverlayPongMessage();
      default:
        _log.fine('Unknown overlay message type: $type');
        return null;
    }
  }
}

/// Sent by main app to overlay to initialize the sticky bubble.
final class OverlayOpenMessage extends OverlayMessage {
  const OverlayOpenMessage({
    required this.path,
    required this.text,
    required this.hash,
    required this.color,
    required this.locked,
    this.title,
  });

  factory OverlayOpenMessage.fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final text = json['text'];
    final hash = json['hash'];
    final color = json['color'];
    final locked = json['locked'];
    final title = json['title'] as String?;

    if (path is! String ||
        text is! String ||
        hash is! String ||
        color is! String ||
        locked is! bool) {
      throw FormatException('Invalid OverlayOpenMessage payload: $json');
    }

    return OverlayOpenMessage(
      path: path,
      text: text,
      hash: hash,
      color: color,
      locked: locked,
      title: title,
    );
  }

  final String path;
  final String text;
  final String hash;
  final String color;
  final bool locked;
  final String? title;

  @override
  Map<String, Object?> toJson() => {
    'v': kOverlayProtocolVersion,
    'type': 'open',
    'path': path,
    'text': text,
    'hash': hash,
    'color': color,
    'locked': locked,
    if (title != null) 'title': title,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayOpenMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          text == other.text &&
          hash == other.hash &&
          color == other.color &&
          locked == other.locked &&
          title == other.title;

  @override
  int get hashCode =>
      path.hashCode ^
      text.hashCode ^
      hash.hashCode ^
      color.hashCode ^
      locked.hashCode ^
      title.hashCode;

  @override
  String toString() =>
      'OverlayOpenMessage(path: $path, hash: $hash, color: $color, locked: $locked, title: $title)';
}

/// Sent by main app to overlay when note text or metadata changed.
final class OverlayUpdateMessage extends OverlayMessage {
  const OverlayUpdateMessage({
    required this.path,
    required this.text,
    required this.hash,
    required this.color,
    required this.locked,
    this.title,
  });

  factory OverlayUpdateMessage.fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final text = json['text'];
    final hash = json['hash'];
    final color = json['color'];
    final locked = json['locked'];
    final title = json['title'] as String?;

    if (path is! String ||
        text is! String ||
        hash is! String ||
        color is! String ||
        locked is! bool) {
      throw FormatException('Invalid OverlayUpdateMessage payload: $json');
    }

    return OverlayUpdateMessage(
      path: path,
      text: text,
      hash: hash,
      color: color,
      locked: locked,
      title: title,
    );
  }

  final String path;
  final String text;
  final String hash;
  final String color;
  final bool locked;
  final String? title;

  @override
  Map<String, Object?> toJson() => {
    'v': kOverlayProtocolVersion,
    'type': 'update',
    'path': path,
    'text': text,
    'hash': hash,
    'color': color,
    'locked': locked,
    if (title != null) 'title': title,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayUpdateMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          text == other.text &&
          hash == other.hash &&
          color == other.color &&
          locked == other.locked &&
          title == other.title;

  @override
  int get hashCode =>
      path.hashCode ^
      text.hashCode ^
      hash.hashCode ^
      color.hashCode ^
      locked.hashCode ^
      title.hashCode;

  @override
  String toString() =>
      'OverlayUpdateMessage(path: $path, hash: $hash, color: $color, locked: $locked, title: $title)';
}

/// Sent by overlay to main app when note body text has been edited.
final class OverlayContentChangedMessage extends OverlayMessage {
  const OverlayContentChangedMessage({
    required this.path,
    required this.text,
    required this.baseHash,
  });

  factory OverlayContentChangedMessage.fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final text = json['text'];
    final baseHash = json['baseHash'];

    if (path is! String || text is! String || baseHash is! String) {
      throw FormatException(
        'Invalid OverlayContentChangedMessage payload: $json',
      );
    }

    return OverlayContentChangedMessage(
      path: path,
      text: text,
      baseHash: baseHash,
    );
  }

  final String path;
  final String text;
  final String baseHash;

  @override
  Map<String, Object?> toJson() => {
    'v': kOverlayProtocolVersion,
    'type': 'contentChanged',
    'path': path,
    'text': text,
    'baseHash': baseHash,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayContentChangedMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          text == other.text &&
          baseHash == other.baseHash;

  @override
  int get hashCode => path.hashCode ^ text.hashCode ^ baseHash.hashCode;

  @override
  String toString() =>
      'OverlayContentChangedMessage(path: $path, baseHash: $baseHash, textLength: ${text.length})';
}

/// Sent by main app to overlay confirming an applied content edit.
final class OverlayAckMessage extends OverlayMessage {
  const OverlayAckMessage({required this.path, required this.hash});

  factory OverlayAckMessage.fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final hash = json['hash'];

    if (path is! String || hash is! String) {
      throw FormatException('Invalid OverlayAckMessage payload: $json');
    }

    return OverlayAckMessage(path: path, hash: hash);
  }

  final String path;
  final String hash;

  @override
  Map<String, Object?> toJson() => {
    'v': kOverlayProtocolVersion,
    'type': 'ack',
    'path': path,
    'hash': hash,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayAckMessage &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          hash == other.hash;

  @override
  int get hashCode => path.hashCode ^ hash.hashCode;

  @override
  String toString() => 'OverlayAckMessage(path: $path, hash: $hash)';
}

/// Sent by overlay to main app when the bubble is closed or dragged to dismiss.
final class OverlayCloseMessage extends OverlayMessage {
  const OverlayCloseMessage({required this.path});

  factory OverlayCloseMessage.fromJson(Map<String, Object?> json) {
    final path = json['path'];
    if (path is! String) {
      throw FormatException('Invalid OverlayCloseMessage payload: $json');
    }
    return OverlayCloseMessage(path: path);
  }

  final String path;

  @override
  Map<String, Object?> toJson() => {
    'v': kOverlayProtocolVersion,
    'type': 'close',
    'path': path,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayCloseMessage &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'OverlayCloseMessage(path: $path)';
}

/// Ping message between engines for connectivity checks.
final class OverlayPingMessage extends OverlayMessage {
  const OverlayPingMessage();

  @override
  Map<String, Object?> toJson() => {
    'v': kOverlayProtocolVersion,
    'type': 'ping',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OverlayPingMessage;

  @override
  int get hashCode => 101;

  @override
  String toString() => 'OverlayPingMessage()';
}

/// Pong reply message between engines for connectivity checks.
final class OverlayPongMessage extends OverlayMessage {
  const OverlayPongMessage();

  @override
  Map<String, Object?> toJson() => {
    'v': kOverlayProtocolVersion,
    'type': 'pong',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OverlayPongMessage;

  @override
  int get hashCode => 102;

  @override
  String toString() => 'OverlayPongMessage()';
}
