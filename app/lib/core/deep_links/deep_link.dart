// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Sealed hierarchy representing all deep links recognized by Tephra.
sealed class DeepLink {
  const DeepLink();

  /// Target vault ID, or null to operate on the currently active vault.
  String? get vaultId;

  /// Serializes this link to a `tephra://` [Uri].
  Uri toUri();

  /// Parses a deep link from [uri].
  ///
  /// Returns null if the scheme is not `tephra`, the host/path is unrecognized,
  /// or required query parameters are missing.
  static DeepLink? parse(Uri uri) {
    if (uri.scheme.toLowerCase() != 'tephra') {
      return null;
    }

    final action = uri.host.isNotEmpty
        ? uri.host.toLowerCase()
        : (uri.pathSegments.isNotEmpty
              ? uri.pathSegments.first.toLowerCase()
              : '');

    final vault = uri.queryParameters['vault'];

    switch (action) {
      case 'open':
        final rawPath = uri.queryParameters['path'];
        if (rawPath == null || rawPath.trim().isEmpty) return null;
        try {
          final path = VaultPath(rawPath);
          return OpenNoteLink(path: path, vaultId: vault);
        } catch (_) {
          return null;
        }

      case 'capture':
        return CaptureLink(vaultId: vault);

      case 'new-sticky':
        return NewStickyLink(vaultId: vault);

      case 'daily':
        return DailyLink(vaultId: vault);

      case 'board':
        return BoardLink(vaultId: vault);

      case 'widget-config':
        final rawWidgetId = uri.queryParameters['widgetId'];
        if (rawWidgetId == null) return null;
        final widgetId = int.tryParse(rawWidgetId);
        if (widgetId == null) return null;
        return WidgetConfigLink(widgetId: widgetId, vaultId: vault);

      default:
        return null;
    }
  }
}

/// Link to open a specific note in the vault (`tephra://open?vault=<v>&path=<p>`).
final class OpenNoteLink extends DeepLink {
  const OpenNoteLink({required this.path, this.vaultId});

  final VaultPath path;
  @override
  final String? vaultId;

  @override
  Uri toUri() => Uri(
    scheme: 'tephra',
    host: 'open',
    queryParameters: {
      if (vaultId != null) 'vault': vaultId,
      'path': path.value,
    },
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenNoteLink &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          vaultId == other.vaultId;

  @override
  int get hashCode => Object.hash(path, vaultId);

  @override
  String toString() => toUri().toString();
}

/// Link to open the quick-capture sheet (`tephra://capture?vault=<v>`).
final class CaptureLink extends DeepLink {
  const CaptureLink({this.vaultId});

  @override
  final String? vaultId;

  @override
  Uri toUri() => Uri(
    scheme: 'tephra',
    host: 'capture',
    queryParameters: {if (vaultId != null) 'vault': vaultId},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureLink &&
          runtimeType == other.runtimeType &&
          vaultId == other.vaultId;

  @override
  int get hashCode => vaultId.hashCode;

  @override
  String toString() => toUri().toString();
}

/// Link to create and open a new sticky note (`tephra://new-sticky?vault=<v>`).
final class NewStickyLink extends DeepLink {
  const NewStickyLink({this.vaultId});

  @override
  final String? vaultId;

  @override
  Uri toUri() => Uri(
    scheme: 'tephra',
    host: 'new-sticky',
    queryParameters: {if (vaultId != null) 'vault': vaultId},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewStickyLink &&
          runtimeType == other.runtimeType &&
          vaultId == other.vaultId;

  @override
  int get hashCode => vaultId.hashCode;

  @override
  String toString() => toUri().toString();
}

/// Link to open today's daily note (`tephra://daily?vault=<v>`).
final class DailyLink extends DeepLink {
  const DailyLink({this.vaultId});

  @override
  final String? vaultId;

  @override
  Uri toUri() => Uri(
    scheme: 'tephra',
    host: 'daily',
    queryParameters: {if (vaultId != null) 'vault': vaultId},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyLink &&
          runtimeType == other.runtimeType &&
          vaultId == other.vaultId;

  @override
  int get hashCode => vaultId.hashCode;

  @override
  String toString() => toUri().toString();
}

/// Link to open the sticky board (`tephra://board?vault=<v>`).
final class BoardLink extends DeepLink {
  const BoardLink({this.vaultId});

  @override
  final String? vaultId;

  @override
  Uri toUri() => Uri(
    scheme: 'tephra',
    host: 'board',
    queryParameters: {if (vaultId != null) 'vault': vaultId},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardLink &&
          runtimeType == other.runtimeType &&
          vaultId == other.vaultId;

  @override
  int get hashCode => vaultId.hashCode;

  @override
  String toString() => toUri().toString();
}

/// Link to choose a sticky for a home screen widget (`tephra://widget-config?widgetId=<n>`).
final class WidgetConfigLink extends DeepLink {
  const WidgetConfigLink({required this.widgetId, this.vaultId});

  final int widgetId;
  @override
  final String? vaultId;

  @override
  Uri toUri() => Uri(
    scheme: 'tephra',
    host: 'widget-config',
    queryParameters: {
      if (vaultId != null) 'vault': vaultId,
      'widgetId': widgetId.toString(),
    },
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetConfigLink &&
          runtimeType == other.runtimeType &&
          widgetId == other.widgetId &&
          vaultId == other.vaultId;

  @override
  int get hashCode => Object.hash(widgetId, vaultId);

  @override
  String toString() => toUri().toString();
}
