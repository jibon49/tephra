// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../../l10n/app_localizations.dart';
import '../data/sticky_repository.dart';
import '../model/sticky.dart';
import '../model/sticky_color.dart';
import '../model/sticky_frontmatter.dart';
import '../ui/sticky_color_picker.dart';

/// Opens the quick editor for a sticky note (dialog on wide screens, bottom sheet on phone).
Future<void> showBoardQuickEditor(
  BuildContext context, {
  required Sticky sticky,
  required StickyRepository repository,
}) async {
  final isDesktop = MediaQuery.of(context).size.width >= 840;

  if (isDesktop) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 520,
          height: 420,
          child: BoardQuickEditor(sticky: sticky, repository: repository),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: BoardQuickEditor(sticky: sticky, repository: repository),
      ),
    );
  }
}

/// Inline editor for sticky note body text, colour, and lock status.
class BoardQuickEditor extends StatefulWidget {
  const BoardQuickEditor({
    super.key,
    required this.sticky,
    required this.repository,
  });

  final Sticky sticky;
  final StickyRepository repository;

  @override
  State<BoardQuickEditor> createState() => _BoardQuickEditorState();
}

class _BoardQuickEditorState extends State<BoardQuickEditor> {
  late TextEditingController _bodyController;
  late StickyColor _color;
  late bool _locked;
  Timer? _idleSaveTimer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController(text: widget.sticky.body);
    _color = widget.sticky.meta.color;
    _locked = widget.sticky.meta.locked;
  }

  @override
  void dispose() {
    _idleSaveTimer?.cancel();
    _save();
    _bodyController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _idleSaveTimer?.cancel();
    _idleSaveTimer = Timer(const Duration(seconds: 1), _save);
  }

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;

    try {
      final split = splitFrontmatter(widget.sticky.text);
      final frontmatterPart = split != null
          ? widget.sticky.text.substring(0, split.bodyStart)
          : '';

      var updatedText = '$frontmatterPart${_bodyController.text}';
      if (_color != widget.sticky.meta.color ||
          _locked != widget.sticky.meta.locked) {
        updatedText = applyStickyPatch(
          updatedText,
          StickyPatch(color: _color, locked: _locked),
        );
      }

      if (updatedText != widget.sticky.text) {
        await widget.repository.setText(widget.sticky.path, updatedText);
      }
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cardColor = Color(_color.argb);
    final textColor = Color(_color.textArgb);

    return Scaffold(
      backgroundColor: cardColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.sticky.title,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Colour picker
          IconButton(
            tooltip: l10n.stickyCommandSetColor,
            icon: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Color(_color.argb),
                shape: BoxShape.circle,
                border: Border.all(color: textColor.withValues(alpha: 0.6)),
              ),
            ),
            onPressed: () async {
              final picked = await showStickyColorPicker(
                context,
                initialColor: _color,
              );
              if (picked != null) {
                setState(() => _color = picked);
                _scheduleSave();
              }
            },
          ),

          // Lock toggle
          IconButton(
            tooltip: _locked
                ? l10n.stickyBannerLocked
                : l10n.stickyBannerUnlocked,
            icon: Icon(
              _locked ? Icons.lock : Icons.lock_open,
              color: _locked ? theme.colorScheme.error : textColor,
              size: 20,
            ),
            onPressed: () {
              setState(() => _locked = !_locked);
              _scheduleSave();
            },
          ),

          IconButton(
            icon: Icon(Icons.close, color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            if (_locked)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: theme.colorScheme.error),
                    const SizedBox(width: 6),
                    Text(
                      l10n.stickyBannerLocked,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TextField(
                controller: _bodyController,
                readOnly: _locked,
                maxLines: null,
                expands: true,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.stickyQuickEditorTitle,
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
                ),
                onChanged: (_) => _scheduleSave(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
