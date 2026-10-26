// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/sticky_color.dart';
import '../model/task_toggle.dart';
import '../ui/sticky_mini_renderer.dart';
import 'overlay_protocol.dart';
import 'overlay_writer.dart';

/// Entry point launched by FlutterOverlayWindow in the secondary overlay engine.
void runOverlayApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

/// Standalone floating sticky overlay widget displaying a draggable bubble when collapsed
/// and a mini editor when expanded.
class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  bool _isExpanded = false;
  bool _isEditing = false;
  String? _path;
  String _text = '';
  String _currentHash = '';
  StickyColor _color = NamedStickyColor.yellow;
  bool _locked = false;
  String _title = '';
  String? _statusBanner;

  String _frontmatterPrefix = '';
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _bodyFocusNode = FocusNode();

  late final OverlayWriterFallback _writer;
  StreamSubscription<dynamic>? _overlayListenerSub;

  @override
  void initState() {
    super.initState();
    _writer = OverlayWriterFallback(
      sendToMain: (msg) async {
        await FlutterOverlayWindow.shareData(msg.toJson());
      },
    );

    _bodyFocusNode.addListener(_onFocusChanged);
    _overlayListenerSub = FlutterOverlayWindow.overlayListener.listen(
      _handleIncomingData,
    );

    // Announce ready / ping to main app
    unawaited(
      FlutterOverlayWindow.shareData(const OverlayPingMessage().toJson()),
    );
  }

  @override
  void dispose() {
    _overlayListenerSub?.cancel();
    _bodyFocusNode.removeListener(_onFocusChanged);
    _bodyFocusNode.dispose();
    _bodyController.dispose();
    _writer.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_bodyFocusNode.hasFocus && _isEditing) {
      _exitEditMode();
    }
  }

  void _handleIncomingData(dynamic data) {
    final message = OverlayMessage.fromDynamic(data);
    if (message == null) return;

    switch (message) {
      case OverlayOpenMessage():
        setState(() {
          _path = message.path;
          _text = message.text;
          _currentHash = message.hash;
          _color = StickyColor.parse(message.color);
          _locked = message.locked;
          _title = message.title ?? VaultPath(message.path).stem;
          _statusBanner = null;
        });

      case OverlayUpdateMessage():
        setState(() {
          _path = message.path;
          _text = message.text;
          _currentHash = message.hash;
          _color = StickyColor.parse(message.color);
          _locked = message.locked;
          if (message.title != null) _title = message.title!;
        });
        if (_isEditing) {
          final split = splitFrontmatter(_text);
          final body = split != null ? _text.substring(split.bodyStart) : _text;
          if (_bodyController.text != body) {
            _bodyController.text = body;
          }
        }

      case OverlayAckMessage():
        _writer.onAckReceived(message.path, message.hash);
        _currentHash = message.hash;

      default:
        break;
    }
  }

  Future<void> _expand() async {
    await FlutterOverlayWindow.resizeOverlay(300, 420, true);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    setState(() {
      _isExpanded = true;
    });
  }

  Future<void> _collapse() async {
    if (_isEditing) {
      _exitEditMode();
    }
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    await FlutterOverlayWindow.resizeOverlay(56, 56, false);
    setState(() {
      _isExpanded = false;
    });
  }

  Future<void> _close() async {
    if (_path != null) {
      await FlutterOverlayWindow.shareData(
        OverlayCloseMessage(path: _path!).toJson(),
      );
    }
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _openInTephra() async {
    if (_path == null) return;
    final uri = Uri.parse(
      'tephra://open?path=${Uri.encodeQueryComponent(_path!)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _enterEditMode() {
    if (_locked) return;
    final split = splitFrontmatter(_text);
    if (split != null) {
      _frontmatterPrefix = _text.substring(0, split.bodyStart);
      _bodyController.text = _text.substring(split.bodyStart);
    } else {
      _frontmatterPrefix = '';
      _bodyController.text = _text;
    }
    setState(() {
      _isEditing = true;
    });
    _bodyFocusNode.requestFocus();
  }

  void _exitEditMode() {
    if (!_isEditing) return;
    final newBody = _bodyController.text;
    final newFullText = '$_frontmatterPrefix$newBody';
    _saveText(newFullText);
    setState(() {
      _isEditing = false;
    });
  }

  void _toggleTask(int line) {
    if (_locked) return;
    final toggled = toggleTaskAtLine(_text, line);
    if (toggled != null) {
      _saveText(toggled);
    }
  }

  void _saveText(String newText) {
    _text = newText;
    if (_path == null) return;

    unawaited(
      _writer
          .sendEdit(
            path: VaultPath(_path!),
            text: newText,
            baseHash: _currentHash,
          )
          .then((status) {
            if (!mounted) return;
            setState(() {
              if (status == OverlaySaveStatus.requiresTephraToSave) {
                _statusBanner = 'Open Tephra to save';
              } else {
                _statusBanner = null;
              }
            });
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        type: MaterialType.transparency,
        child: _isExpanded ? _buildExpanded() : _buildCollapsed(),
      ),
    );
  }

  Widget _buildCollapsed() {
    final bgColor = Color(_color.argb);
    final iconColor = Color(_color.textArgb);

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _expand,
        onPanUpdate: (details) async {
          final pos = await FlutterOverlayWindow.getOverlayPosition();
          await FlutterOverlayWindow.moveOverlay(
            OverlayPosition(
              pos.x + details.delta.dx.round(),
              pos.y + details.delta.dy.round(),
            ),
          );
        },
        onPanEnd: (details) async {
          final screenHeight = MediaQuery.sizeOf(context).height;
          final pos = await FlutterOverlayWindow.getOverlayPosition();
          // If within 120 px of the bottom of the screen, close bubble
          if (pos.y > (screenHeight > 0 ? screenHeight - 120 : 680)) {
            await _close();
          }
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.note_alt_outlined, color: iconColor, size: 28),
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    final bgColor = Color(_color.argb);
    final textColor = Color(_color.textArgb);

    return Container(
      width: 300,
      height: 420,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: textColor.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _title.isNotEmpty ? _title : 'Sticky',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(Icons.open_in_new, color: textColor),
                  tooltip: 'Open in Tephra',
                  onPressed: _openInTephra,
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(Icons.close_fullscreen, color: textColor),
                  tooltip: 'Collapse',
                  onPressed: _collapse,
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(Icons.close, color: textColor),
                  tooltip: 'Close',
                  onPressed: _close,
                ),
              ],
            ),
          ),

          // Status banner if any
          if (_statusBanner != null)
            Container(
              color: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                _statusBanner!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: _isEditing
                  ? TextField(
                      controller: _bodyController,
                      focusNode: _bodyFocusNode,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final recombined = '$_frontmatterPrefix$val';
                        _saveText(recombined);
                      },
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _enterEditMode,
                      child: StickyMiniRenderer(
                        text: _text,
                        textColor: textColor,
                        onToggleTask: _locked ? null : _toggleTask,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
