// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:isolate';

import 'package:tephra_markdown/tephra_markdown.dart';

import 'block_decorator.dart';
import 'chunk_splitter.dart';
import 'lp_decoration.dart';
import 'lp_options.dart';

/// Statistics recorded for the most recent parse / edit in [LivePreviewEngine].
final class LpEngineStats {
  const LpEngineStats({
    required this.chunksReparsed,
    required this.chunkCount,
    required this.microseconds,
  });

  final int chunksReparsed;
  final int chunkCount;
  final int microseconds;

  @override
  String toString() =>
      'LpEngineStats(reparsed: $chunksReparsed, chunks: $chunkCount, $microseconds us)';
}

final class _ChunkData {
  _ChunkData({
    required this.start,
    required this.end,
    required this.relativeDecorations,
  });

  int start;
  int end;
  final List<LpDecoration> relativeDecorations;
}

/// Pure Dart incremental Live Preview engine that generates and maintains decorations.
final class LivePreviewEngine {
  LivePreviewEngine({
    this.options = const LpOptions(),
    ParsedNote Function(String)? parse,
  }) : _parse = parse ?? MarkdownParser.parse;

  LpOptions options;
  final ParsedNote Function(String) _parse;

  List<_ChunkData> _chunks = [];
  int _revision = 0;
  LpEngineStats _lastStats = const LpEngineStats(
    chunksReparsed: 0,
    chunkCount: 0,
    microseconds: 0,
  );

  int get revision => _revision;
  LpEngineStats get lastStats => _lastStats;

  /// Full recompute of all decorations for [text].
  void setText(String text, {bool sync = false}) {
    final sw = Stopwatch()..start();

    if (text.length > 50000 && !sync && _parse == MarkdownParser.parse) {
      _chunks = [];
      _revision++;
      final currentOptions = options;
      unawaited(
        Isolate.run(() {
          return _computeAllChunks(text, currentOptions);
        }).then((result) {
          _chunks = result;
          _revision++;
          sw.stop();
          _lastStats = LpEngineStats(
            chunksReparsed: result.length,
            chunkCount: result.length,
            microseconds: sw.elapsedMicroseconds,
          );
        }),
      );
      return;
    }

    _chunks = _computeAllChunksSync(text, options, _parse);
    _revision++;
    sw.stop();
    _lastStats = LpEngineStats(
      chunksReparsed: _chunks.length,
      chunkCount: _chunks.length,
      microseconds: sw.elapsedMicroseconds,
    );
  }

  /// Incrementally updates decorations for an edit.
  void applyEdit({
    required int start,
    required int deletedLength,
    required String insertedText,
    required String newText,
  }) {
    final sw = Stopwatch()..start();
    final delta = insertedText.length - deletedLength;
    final newChunkSpans = splitChunks(newText);
    var chunksReparsed = 0;
    final updatedChunks = <_ChunkData>[];

    final oldByStart = <int, _ChunkData>{
      for (final oc in _chunks) oc.start: oc,
    };

    for (final c in newChunkSpans) {
      var reused = false;

      // (i) Entirely before the edit
      if (c.end <= start) {
        final old = oldByStart[c.start];
        if (old != null && old.end == c.end) {
          updatedChunks.add(
            _ChunkData(
              start: c.start,
              end: c.end,
              relativeDecorations: old.relativeDecorations,
            ),
          );
          reused = true;
        }
      }

      // (ii) Entirely after the edit
      if (!reused && c.start >= start + insertedText.length) {
        final expectedOldStart = c.start - delta;
        final expectedOldEnd = c.end - delta;
        if (expectedOldStart >= start + deletedLength) {
          final old = oldByStart[expectedOldStart];
          if (old != null && old.end == expectedOldEnd) {
            updatedChunks.add(
              _ChunkData(
                start: c.start,
                end: c.end,
                relativeDecorations: old.relativeDecorations,
              ),
            );
            reused = true;
          }
        }
      }

      if (!reused) {
        chunksReparsed++;
        final chunkStr = newText.substring(c.start, c.end);
        final parsed = _parse(chunkStr);
        final decs = decorateChunk(chunkStr, parsed, 0, options);
        updatedChunks.add(
          _ChunkData(start: c.start, end: c.end, relativeDecorations: decs),
        );
      }
    }

    _chunks = updatedChunks;
    _revision++;
    sw.stop();
    _lastStats = LpEngineStats(
      chunksReparsed: chunksReparsed,
      chunkCount: _chunks.length,
      microseconds: sw.elapsedMicroseconds,
    );
  }

  /// Returns all decorations overlapping `[start, end)`.
  List<LpDecoration> decorationsFor(int start, int end) {
    if (_chunks.isEmpty || start >= end) return const [];

    final result = <LpDecoration>[];
    for (final chunk in _chunks) {
      if (chunk.end <= start) continue;
      if (chunk.start >= end) break;

      final chunkStart = chunk.start;
      for (final d in chunk.relativeDecorations) {
        final absStart = d.start + chunkStart;
        final absEnd = d.end + chunkStart;
        if (absEnd > start && absStart < end) {
          result.add(_shiftDecoration(d, chunkStart));
        }
      }
    }

    result.sort(compareDecorations);
    return result;
  }
}

List<_ChunkData> _computeAllChunksSync(
  String text,
  LpOptions options,
  ParsedNote Function(String) parse,
) {
  final spans = splitChunks(text);
  final list = <_ChunkData>[];
  for (final s in spans) {
    final chunkStr = text.substring(s.start, s.end);
    final parsed = parse(chunkStr);
    final decs = decorateChunk(chunkStr, parsed, 0, options);
    list.add(_ChunkData(start: s.start, end: s.end, relativeDecorations: decs));
  }
  return list;
}

List<_ChunkData> _computeAllChunks(String text, LpOptions options) {
  return _computeAllChunksSync(text, options, MarkdownParser.parse);
}

LpDecoration _shiftDecoration(LpDecoration d, int delta) {
  final reveal = d.reveal != null
      ? LpReveal(d.reveal!.start + delta, d.reveal!.end + delta)
      : null;
  if (d is LpHide) {
    return LpHide(d.start + delta, d.end + delta, reveal: reveal);
  }
  if (d is LpStyle) {
    return LpStyle(
      d.start + delta,
      d.end + delta,
      d.kind,
      level: d.level,
      data: d.data,
      reveal: reveal,
    );
  }
  if (d is LpReplaceChar) {
    return LpReplaceChar(d.start + delta, d.end + delta, d.char);
  }
  if (d is LpWidget) {
    var data = d.data;
    if (d.kind == LpWidgetKind.table && delta != 0) {
      final cellRanges = d.data['cellRanges'];
      if (cellRanges is List) {
        final shifted = <List<List<int>>>[];
        for (final row in cellRanges) {
          if (row is List) {
            final rowShifted = <List<int>>[];
            for (final cell in row) {
              if (cell is List && cell.length == 2) {
                rowShifted.add([
                  (cell[0] as int) + delta,
                  (cell[1] as int) + delta,
                ]);
              }
            }
            shifted.add(rowShifted);
          }
        }
        data = {...d.data, 'cellRanges': shifted};
      }
    }
    return LpWidget(
      d.start + delta,
      d.end + delta,
      d.kind,
      data: data,
      reveal: reveal,
    );
  }
  throw UnimplementedError('Unsupported decoration: ${d.runtimeType}');
}
