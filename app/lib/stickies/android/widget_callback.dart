// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../../core/headless_config.dart';
import '../data/sticky_file_writer.dart';
import '../model/sticky.dart';
import '../model/sticky_meta.dart';
import '../model/task_toggle.dart';
import 'widget_data.dart';

/// Result of attempting to toggle a task line from a widget.
sealed class WidgetToggleResult {
  const WidgetToggleResult();
}

/// The task line was successfully toggled and saved to disk.
final class WidgetToggleSuccess extends WidgetToggleResult {
  const WidgetToggleSuccess(this.newText);
  final String newText;
}

/// The note's protocol hash did not match the widget's hash; line was not toggled.
final class WidgetToggleStaleHash extends WidgetToggleResult {
  const WidgetToggleStaleHash();
}

/// The specified line is not a task item.
final class WidgetToggleNotTask extends WidgetToggleResult {
  const WidgetToggleNotTask();
}

/// The note file does not exist.
final class WidgetToggleFileNotFound extends WidgetToggleResult {
  const WidgetToggleFileNotFound();
}

/// A concurrent edit changed the file on disk between read and write.
final class WidgetToggleConflict extends WidgetToggleResult {
  const WidgetToggleConflict();
}

/// Pure helper executing the task toggle logic against a [VaultFileSystem].
Future<WidgetToggleResult> handleWidgetToggle(
  VaultFileSystem fs,
  String path,
  int line,
  String hash,
) async {
  final vaultPath = VaultPath(path);
  final List<int> bytes;
  try {
    bytes = await fs.readBytes(vaultPath);
  } on FileNotFoundException {
    return const WidgetToggleFileNotFound();
  } catch (_) {
    return const WidgetToggleFileNotFound();
  }

  final doc = TextDocument.decode(bytes);
  final currentProtocolHash = stickyProtocolHash(doc.text);

  // Never toggle a line if the note content has changed since the widget was rendered.
  if (currentProtocolHash != hash) {
    return const WidgetToggleStaleHash();
  }

  final newText = toggleTaskAtLine(doc.text, line);
  if (newText == null) {
    return const WidgetToggleNotTask();
  }

  final fileBytesHash = contentHash(bytes);
  final writer = StickyFileWriter(fs);
  final writtenHash = await writer.writeIfUnchanged(
    vaultPath,
    fileBytesHash,
    newText,
  );

  if (writtenHash == null) {
    return const WidgetToggleConflict();
  }

  return WidgetToggleSuccess(newText);
}

/// Background callback triggered when a user taps a task checkbox in an Android widget.
@pragma('vm:entry-point')
Future<void> stickyWidgetCallback(Uri? uri) async {
  if (uri == null) return;

  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Read HeadlessConfig from application support directory
  final Directory appSupportDir;
  try {
    appSupportDir = await getApplicationSupportDirectory();
  } catch (_) {
    return;
  }

  final configFile = File(
    p.join(appSupportDir.path, HeadlessConfig.defaultFileName),
  );
  final config = await HeadlessConfig.load(configFile);
  if (config == null || config.fsKind != 'io') {
    return;
  }

  final widgetIdStr = uri.queryParameters['widgetId'];
  final lineStr = uri.queryParameters['line'];
  final hash = uri.queryParameters['hash'];
  if (widgetIdStr == null || lineStr == null || hash == null) return;

  final widgetId = int.tryParse(widgetIdStr);
  final line = int.tryParse(lineStr);
  if (widgetId == null || line == null) return;

  // Read sticky_widget_paths to find which note this widget displays
  final pathsRaw = await HomeWidget.getWidgetData<String>(
    'sticky_widget_paths',
  );
  if (pathsRaw == null) return;

  final Map<String, Object?> pathsMap;
  try {
    final decoded = jsonDecode(pathsRaw);
    if (decoded is! Map) return;
    pathsMap = decoded.cast<String, Object?>();
  } catch (_) {
    return;
  }

  final notePath = pathsMap[widgetId.toString()] as String?;
  if (notePath == null || notePath.isEmpty) return;

  final fs = IoVaultFileSystem(config.vaultRoot);
  try {
    await handleWidgetToggle(fs, notePath, line, hash);

    // Read current note text from disk to refresh the widget
    try {
      final vaultPath = VaultPath(notePath);
      final bytes = await fs.readBytes(vaultPath);
      final doc = TextDocument.decode(bytes);
      final stat = await fs.stat(vaultPath);
      final parsed = MarkdownParser.parse(doc.text);
      final meta = StickyMeta.fromFrontmatter(parsed.frontmatter);

      final sticky = Sticky(
        path: vaultPath,
        meta: meta,
        text: doc.text,
        hash: contentHash(bytes),
        modified: stat?.modified ?? DateTime.now(),
      );

      final widgetJson = stickyWidgetJson(
        sticky,
        vaultId: config.vaultId,
        configured: true,
      );
      await HomeWidget.saveWidgetData<String>(
        'sticky_widget_$widgetId',
        jsonEncode(widgetJson),
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.tephra.app.StickyWidgetProvider',
      );
    } catch (_) {
      // Note may have been deleted
      final widgetJson = stickyWidgetJson(
        null,
        vaultId: config.vaultId,
        configured: true,
        missingPath: notePath,
      );
      await HomeWidget.saveWidgetData<String>(
        'sticky_widget_$widgetId',
        jsonEncode(widgetJson),
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.tephra.app.StickyWidgetProvider',
      );
    }
  } finally {
    await fs.dispose();
  }
}
