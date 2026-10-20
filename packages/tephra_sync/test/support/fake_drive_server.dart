// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Injected fault specifications for [FakeDriveServer].
class FakeDriveFaults {
  FakeDriveFaults({
    this.failNextRequests = 0,
    this.statusCode = 500,
    this.reason,
    this.delay,
    this.dropConnectionMidUpload = false,
    this.quotaLimitBytes,
    this.revokeToken = false,
    this.randomFailureRate = 0.0,
  });

  int failNextRequests;
  int statusCode;
  String? reason;
  Duration? delay;
  bool dropConnectionMidUpload;
  int? quotaLimitBytes;
  bool revokeToken;
  double randomFailureRate;
}

class FakeDriveFile {
  FakeDriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.parents,
    Map<String, String>? appProperties,
    this.trashed = false,
    DateTime? createdTime,
    DateTime? modifiedTime,
    this.content,
  }) : appProperties = appProperties ?? {},
       createdTime = createdTime ?? DateTime.now().toUtc(),
       modifiedTime = modifiedTime ?? DateTime.now().toUtc();

  final String id;
  String name;
  String mimeType;
  List<String> parents;
  Map<String, String> appProperties;
  bool trashed;
  DateTime createdTime;
  DateTime modifiedTime;
  Uint8List? content;

  int get size => content?.length ?? 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mimeType': mimeType,
    'parents': parents,
    'appProperties': appProperties,
    'trashed': trashed,
    'size': size.toString(),
    'createdTime': createdTime.toIso8601String(),
    'modifiedTime': modifiedTime.toIso8601String(),
  };
}

class FakeDriveChange {
  FakeDriveChange({
    required this.seq,
    required this.fileId,
    required this.removed,
    this.file,
  });

  final int seq;
  final String fileId;
  final bool removed;
  final FakeDriveFile? file;

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'removed': removed,
    if (file != null) 'file': file!.toJson(),
  };
}

/// In-memory fake Google Drive v3 HTTP server for integration and fault testing.
class FakeDriveServer {
  FakeDriveServer({FakeDriveFaults? faults})
    : faults = faults ?? FakeDriveFaults();

  late final HttpServer _server;
  final FakeDriveFaults faults;

  final Map<String, FakeDriveFile> files = {};
  final List<FakeDriveChange> changes = [];
  final List<String> requestLog = [];

  int _nextFileId = 1;
  int _nextChangeSeq = 1;

  String get rootUrl => 'http://127.0.0.1:${_server.port}/';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handleRequest);
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  void _recordChange(FakeDriveFile file, {bool removed = false}) {
    changes.add(
      FakeDriveChange(
        seq: _nextChangeSeq++,
        fileId: file.id,
        removed: removed || file.trashed,
        file: file,
      ),
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    requestLog.add('${request.method} ${request.uri.path}');

    if (faults.delay != null) {
      await Future<void>.delayed(faults.delay!);
    }

    if (faults.revokeToken) {
      _sendError(request, 401, 'Invalid Credentials', 'authError');
      return;
    }

    if (faults.failNextRequests > 0) {
      faults.failNextRequests--;
      if (faults.dropConnectionMidUpload) {
        final socket = await request.response.detachSocket();
        socket.destroy();
        return;
      }
      _sendError(
        request,
        faults.statusCode,
        'Fault Injected',
        faults.reason ?? 'serverError',
      );
      return;
    }

    try {
      final path = request.uri.path;
      final method = request.method;

      if (path.startsWith('/drive/v3/about')) {
        _handleAbout(request);
      } else if (path.startsWith('/drive/v3/changes/startPageToken')) {
        _handleStartPageToken(request);
      } else if (path.startsWith('/drive/v3/changes')) {
        _handleChangesList(request);
      } else if (path == '/drive/v3/files' ||
          path == '/upload/drive/v3/files') {
        if (method == 'GET') {
          _handleFilesList(request);
        } else if (method == 'POST') {
          await _handleFileCreate(request);
        } else {
          _sendError(request, 405, 'Method Not Allowed', 'methodNotAllowed');
        }
      } else if (path.startsWith('/drive/v3/files/') ||
          path.startsWith('/upload/drive/v3/files/')) {
        final fileId = path.split('/').last;
        if (method == 'GET') {
          _handleFileGet(request, fileId);
        } else if (method == 'PATCH') {
          await _handleFilePatch(request, fileId);
        } else {
          _sendError(request, 405, 'Method Not Allowed', 'methodNotAllowed');
        }
      } else {
        _sendError(request, 404, 'Not Found', 'notFound');
      }
    } catch (e, st) {
      _sendError(request, 500, 'Server Exception: $e $st', 'serverError');
    }
  }

  void _handleAbout(HttpRequest request) {
    int usage = 0;
    for (final f in files.values) {
      if (!f.trashed) {
        usage += f.size;
      }
    }

    final limit = faults.quotaLimitBytes;
    _sendJson(request, {
      'storageQuota': {
        'usage': usage.toString(),
        if (limit != null) 'limit': limit.toString(),
      },
    });
  }

  void _handleStartPageToken(HttpRequest request) {
    _sendJson(request, {'startPageToken': _nextChangeSeq.toString()});
  }

  void _handleChangesList(HttpRequest request) {
    final pageTokenStr = request.uri.queryParameters['pageToken'];
    final pageToken = int.tryParse(pageTokenStr ?? '0') ?? 0;

    final matching = changes.where((c) => c.seq >= pageToken).toList();

    _sendJson(request, {
      'changes': matching.map((c) => c.toJson()).toList(),
      'newStartPageToken': _nextChangeSeq.toString(),
    });
  }

  void _handleFilesList(HttpRequest request) {
    final q = request.uri.queryParameters['q'];
    final pageSize =
        int.tryParse(request.uri.queryParameters['pageSize'] ?? '100') ?? 100;
    final pageToken =
        int.tryParse(request.uri.queryParameters['pageToken'] ?? '0') ?? 0;

    var matched = files.values.toList();
    if (q != null && q.isNotEmpty) {
      matched = matched.where((f) => _matchesQuery(f, q)).toList();
    }

    final start = pageToken.clamp(0, matched.length);
    final end = (start + pageSize).clamp(0, matched.length);
    final paged = matched.sublist(start, end);

    String? nextPageToken;
    if (end < matched.length) {
      nextPageToken = end.toString();
    }

    _sendJson(request, {
      'files': paged.map((f) => f.toJson()).toList(),
      if (nextPageToken != null) 'nextPageToken': nextPageToken,
    });
  }

  static List<String> _splitQueryClauses(String q) {
    final clauses = <String>[];
    int braceDepth = 0;
    int start = 0;
    for (int i = 0; i < q.length; i++) {
      if (q[i] == '{') {
        braceDepth++;
      } else if (q[i] == '}') {
        braceDepth--;
      } else if (braceDepth == 0 &&
          i + 5 <= q.length &&
          q.substring(i, i + 5) == ' and ') {
        clauses.add(q.substring(start, i).trim());
        start = i + 5;
        i = start - 1;
      }
    }
    if (start < q.length) {
      clauses.add(q.substring(start).trim());
    }
    return clauses;
  }

  bool _matchesQuery(FakeDriveFile file, String q) {
    // Queries in Drive format: clause AND clause AND clause
    final parts = _splitQueryClauses(q);
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed == 'trashed = false') {
        if (file.trashed) return false;
      } else if (trimmed.contains('in parents')) {
        final parentId = RegExp(r"'([^']+)'\s+in\s+parents")
            .firstMatch(trimmed)
            ?.group(1);
        if (parentId != null && !file.parents.contains(parentId)) {
          return false;
        }
      } else if (trimmed.startsWith('name =')) {
        final name = RegExp(r"name\s*=\s*'([^']*)'")
            .firstMatch(trimmed)
            ?.group(1);
        if (name != null && file.name != name) {
          return false;
        }
      } else if (trimmed.startsWith('mimeType =')) {
        final mime = RegExp(r"mimeType\s*=\s*'([^']*)'")
            .firstMatch(trimmed)
            ?.group(1);
        if (mime != null && file.mimeType != mime) {
          return false;
        }
      } else if (trimmed.contains('appProperties has')) {
        final key = RegExp(r"key='([^']+)'").firstMatch(trimmed)?.group(1);
        final value = RegExp(r"value='([^']+)'").firstMatch(trimmed)?.group(1);
        if (key != null && value != null) {
          if (file.appProperties[key] != value) {
            return false;
          }
        }
      }
    }
    return true;
  }

  Future<void> _handleFileCreate(HttpRequest request) async {
    final uploadType = request.uri.queryParameters['uploadType'];
    final bodyBytes = await _readBodyBytes(request);

    String name = 'untitled';
    String mimeType = 'application/octet-stream';
    List<String> parents = [];
    Map<String, String> appProperties = {};
    Uint8List? content;

    if (uploadType == 'multipart') {
      final parsed = _parseMultipartRelated(
        bodyBytes,
        request.headers.contentType,
      );
      if (parsed.metadata != null) {
        final meta = parsed.metadata!;
        name = (meta['name'] as String?) ?? name;
        mimeType = (meta['mimeType'] as String?) ?? mimeType;
        parents = (meta['parents'] as List?)?.cast<String>() ?? parents;
        appProperties =
            (meta['appProperties'] as Map?)?.cast<String, String>() ??
            appProperties;
      }
      content = parsed.content;
    } else {
      if (bodyBytes.isNotEmpty) {
        try {
          final meta =
              jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
          name = (meta['name'] as String?) ?? name;
          mimeType = (meta['mimeType'] as String?) ?? mimeType;
          parents = (meta['parents'] as List?)?.cast<String>() ?? parents;
          appProperties =
              (meta['appProperties'] as Map?)?.cast<String, String>() ??
              appProperties;
        } catch (_) {
          content = bodyBytes;
        }
      }
    }

    final id = 'fake_file_${_nextFileId++}';
    final file = FakeDriveFile(
      id: id,
      name: name,
      mimeType: mimeType,
      parents: parents,
      appProperties: appProperties,
      content: content,
    );

    files[id] = file;
    _recordChange(file);

    _sendJson(request, file.toJson(), status: 200);
  }

  void _handleFileGet(HttpRequest request, String fileId) {
    final file = files[fileId];
    if (file == null || file.trashed) {
      _sendError(request, 404, 'File not found: $fileId', 'notFound');
      return;
    }

    if (request.uri.queryParameters['alt'] == 'media') {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.parse(file.mimeType);
      request.response.headers.contentLength = file.size;
      request.response.add(file.content ?? Uint8List(0));
      request.response.close();
    } else {
      _sendJson(request, file.toJson());
    }
  }

  Future<void> _handleFilePatch(HttpRequest request, String fileId) async {
    final file = files[fileId];
    if (file == null) {
      _sendError(request, 404, 'File not found: $fileId', 'notFound');
      return;
    }

    final uploadType = request.uri.queryParameters['uploadType'];
    final bodyBytes = await _readBodyBytes(request);

    if (uploadType == 'multipart') {
      final parsed = _parseMultipartRelated(
        bodyBytes,
        request.headers.contentType,
      );
      if (parsed.content != null) {
        file.content = parsed.content;
      }
      if (parsed.metadata != null) {
        final meta = parsed.metadata!;
        if (meta.containsKey('trashed')) {
          file.trashed = meta['trashed'] as bool;
        }
        if (meta.containsKey('name')) {
          file.name = meta['name'] as String;
        }
        if (meta.containsKey('appProperties')) {
          file.appProperties.addAll(
            (meta['appProperties'] as Map).cast<String, String>(),
          );
        }
      }
    } else {
      if (bodyBytes.isNotEmpty) {
        try {
          final meta =
              jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
          if (meta.containsKey('trashed')) {
            file.trashed = meta['trashed'] as bool;
          }
          if (meta.containsKey('name')) {
            file.name = meta['name'] as String;
          }
          if (meta.containsKey('appProperties')) {
            file.appProperties.addAll(
              (meta['appProperties'] as Map).cast<String, String>(),
            );
          }
        } catch (_) {
          file.content = bodyBytes;
        }
      }
    }

    file.modifiedTime = DateTime.now().toUtc();
    _recordChange(file);

    _sendJson(request, file.toJson());
  }

  _ParsedMultipart _parseMultipartRelated(
    Uint8List body,
    ContentType? contentType,
  ) {
    final boundary = contentType?.parameters['boundary'];
    if (boundary == null) {
      return _ParsedMultipart(null, body);
    }

    final delimiter = utf8.encode('--$boundary');
    final parts = _splitBytes(body, delimiter);

    Map<String, dynamic>? metadata;
    Uint8List? content;

    for (final part in parts) {
      if (part.isEmpty) continue;
      final headerEnd = _indexOfSublist(part, utf8.encode('\r\n\r\n'));
      if (headerEnd == -1) continue;

      final headerStr = utf8.decode(part.sublist(0, headerEnd));
      var data = part.sublist(headerEnd + 4);
      if (data.length >= 2 &&
          data[data.length - 2] == 13 &&
          data[data.length - 1] == 10) {
        data = data.sublist(0, data.length - 2);
      }

      if (headerStr.contains('application/json')) {
        try {
          var jsonBytes = data;
          if (headerStr.toLowerCase().contains('base64')) {
            jsonBytes = Uint8List.fromList(
              base64Decode(utf8.decode(data).replaceAll(RegExp(r'\s+'), '')),
            );
          }
          metadata = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
        } catch (_) {}
      } else {
        if (headerStr.toLowerCase().contains('base64')) {
          content = Uint8List.fromList(
            base64Decode(utf8.decode(data).replaceAll(RegExp(r'\s+'), '')),
          );
        } else {
          content = Uint8List.fromList(data);
        }
      }
    }

    return _ParsedMultipart(metadata, content);
  }

  static List<Uint8List> _splitBytes(Uint8List source, List<int> pattern) {
    final results = <Uint8List>[];
    int start = 0;
    while (true) {
      final index = _indexOfSublist(source, pattern, start);
      if (index == -1) {
        results.add(Uint8List.fromList(source.sublist(start)));
        break;
      }
      results.add(Uint8List.fromList(source.sublist(start, index)));
      start = index + pattern.length;
    }
    return results;
  }

  static int _indexOfSublist(
    List<int> source,
    List<int> pattern, [
    int start = 0,
  ]) {
    for (int i = start; i <= source.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  Future<Uint8List> _readBodyBytes(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  void _sendJson(
    HttpRequest request,
    Map<String, dynamic> json, {
    int status = 200,
  }) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(json));
    request.response.close();
  }

  void _sendError(
    HttpRequest request,
    int status,
    String message,
    String reason,
  ) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'error': {
          'code': status,
          'message': message,
          'errors': [
            {'reason': reason, 'message': message},
          ],
        },
      }),
    );
    request.response.close();
  }
}

class _ParsedMultipart {
  _ParsedMultipart(this.metadata, this.content);
  final Map<String, dynamic>? metadata;
  final Uint8List? content;
}
