// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';

import '../core/platform/share_intent_service.dart';
import '../l10n/app_localizations.dart';
import '../settings/providers.dart';
import '../vault/providers.dart';
import '../workspace/open_file.dart';
import 'providers.dart';
import 'share_intake.dart';

/// Target choice for saving captured content.
enum CaptureTargetChoice { dailyNote, newNote, inbox }

/// Responsive capture screen / dialog for processing incoming shares and quick capture notes.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({
    super.key,
    required this.initialDraft,
    this.isShare = false,
    this.standaloneLaunch = false,
  });

  final CaptureDraft initialDraft;
  final bool isShare;
  final bool standaloneLaunch;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  late final TextEditingController _textController;
  late final List<SharedFile> _files;
  late CaptureTargetChoice _targetChoice;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialDraft.text);
    _files = List<SharedFile>.from(widget.initialDraft.files);

    final settings = ref.read(vaultSettingsProvider);
    final defaultTarget = widget.isShare
        ? settings.shareTarget
        : settings.quickCaptureTarget;

    switch (defaultTarget) {
      case 'newNote':
        _targetChoice = CaptureTargetChoice.newNote;
      case 'inbox':
        _targetChoice = CaptureTargetChoice.inbox;
      case 'dailyNote':
      default:
        _targetChoice = CaptureTargetChoice.dailyNote;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final session = ref.read(vaultSessionProvider);
    final l10n = AppLocalizations.of(context);

    if (session == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.captureNoVault)));
      return;
    }

    final service = ref.read(captureServiceProvider);
    if (service == null) return;

    setState(() => _saving = true);

    final draft = CaptureDraft(
      text: _textController.text,
      files: _files,
      title: widget.initialDraft.title,
    );

    try {
      final VaultPath savedPath;
      switch (_targetChoice) {
        case CaptureTargetChoice.newNote:
          savedPath = await service.saveAsNewNote(draft);
        case CaptureTargetChoice.dailyNote:
          savedPath = await service.appendToDailyNote(draft);
        case CaptureTargetChoice.inbox:
          savedPath = await service.appendToInbox(draft);
      }

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved to ${savedPath.name}'),
          action: SnackBarAction(
            label: l10n.captureOpen,
            onPressed: () {
              openFile(ref, savedPath);
            },
          ),
        ),
      );

      if (widget.standaloneLaunch) {
        Future<void>.delayed(const Duration(milliseconds: 1500), () {
          SystemNavigator.pop();
        });
      } else {
        Navigator.of(context).maybePop(savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save capture: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 840;

    final content = _buildBody(context);

    if (isDesktop) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
          child: Padding(padding: const EdgeInsets.all(20), child: content),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).captureTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _handleSave,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: content),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target Segmented Control
        SegmentedButton<CaptureTargetChoice>(
          segments: [
            ButtonSegment(
              value: CaptureTargetChoice.dailyNote,
              label: Text(l10n.captureTargetDaily),
              icon: const Icon(Icons.calendar_today, size: 16),
            ),
            ButtonSegment(
              value: CaptureTargetChoice.newNote,
              label: Text(l10n.captureTargetNew),
              icon: const Icon(Icons.note_add_outlined, size: 16),
            ),
            ButtonSegment(
              value: CaptureTargetChoice.inbox,
              label: Text(l10n.captureTargetInbox),
              icon: const Icon(Icons.inbox_outlined, size: 16),
            ),
          ],
          selected: {_targetChoice},
          onSelectionChanged: (set) {
            setState(() => _targetChoice = set.first);
          },
        ),
        const SizedBox(height: 12),

        // Files chip list
        if (_files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < _files.length; i++)
                  Chip(
                    avatar: Icon(
                      _files[i].mimeType?.startsWith('image/') == true
                          ? Icons.image
                          : Icons.attach_file,
                      size: 16,
                    ),
                    label: Text(
                      p.basename(_files[i].path),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onDeleted: () {
                      setState(() => _files.removeAt(i));
                    },
                  ),
              ],
            ),
          ),

        // Text input field
        Expanded(
          child: TextField(
            controller: _textController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: l10n.captureTextPlaceholder,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Save Button (dialog layout)
        if (MediaQuery.sizeOf(context).width >= 840)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(l10n.captureSave),
                onPressed: _saving ? null : _handleSave,
              ),
            ],
          ),
      ],
    );
  }
}
