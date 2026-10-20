// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'diff_model.dart';

/// A responsive widget displaying differences between two text versions.
///
/// On wider displays (≥ 840 dp), defaults to a side-by-side synchronized view.
/// On narrower displays (< 840 dp), defaults to a stacked unified inline diff.
class DiffView extends StatefulWidget {
  const DiffView({
    super.key,
    required this.oldText,
    required this.newText,
    this.initialMode,
    this.oldTitle,
    this.newTitle,
    this.showModeToggle = true,
  });

  /// The original / winning text (version A, e.g. "Their version").
  final String oldText;

  /// The modified / conflicting text (version B, e.g. "Your version").
  final String newText;

  /// Initial display mode override. If null, adapts responsively to width.
  final DiffDisplayMode? initialMode;

  /// Header title for the original text column/section.
  final String? oldTitle;

  /// Header title for the modified text column/section.
  final String? newTitle;

  /// Whether to render the mode toggle button in the header toolbar.
  final bool showModeToggle;

  @override
  State<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> {
  DiffDisplayMode? _userSelectedMode;
  List<DiffLine>? _diffLines;
  List<SideBySideRow>? _sideBySideRows;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _userSelectedMode = widget.initialMode;
    _computeDiff();
  }

  @override
  void didUpdateWidget(covariant DiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldText != widget.oldText ||
        oldWidget.newText != widget.newText) {
      _computeDiff();
    }
    if (oldWidget.initialMode != widget.initialMode &&
        widget.initialMode != null) {
      _userSelectedMode = widget.initialMode;
    }
  }

  Future<void> _computeDiff() async {
    setState(() => _isLoading = true);
    final diffs = await computeLineDiff(widget.oldText, widget.newText);
    final rows = sideBySide(diffs);
    if (!mounted) return;
    setState(() {
      _diffLines = diffs;
      _sideBySideRows = rows;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final diffs = _diffLines ?? const [];
    final rows = _sideBySideRows ?? const [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;
        final effectiveMode =
            _userSelectedMode ??
            (isDesktop ? DiffDisplayMode.sideBySide : DiffDisplayMode.inline);

        return Column(
          children: [
            if (widget.showModeToggle)
              _buildHeaderToolbar(
                context,
                l10n,
                theme,
                effectiveMode,
                isDesktop,
              ),
            Expanded(
              child: effectiveMode == DiffDisplayMode.sideBySide
                  ? _buildSideBySideView(context, theme, l10n, rows)
                  : _buildInlineView(context, theme, l10n, diffs),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderToolbar(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    DiffDisplayMode mode,
    bool isDesktop,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.difference_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.oldTitle ?? l10n.conflictTheirVersion}  ↔  ${widget.newTitle ?? l10n.conflictYourVersion}',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<DiffDisplayMode>(
            segments: [
              ButtonSegment<DiffDisplayMode>(
                value: DiffDisplayMode.sideBySide,
                label: isDesktop ? Text(l10n.diffSideBySide) : null,
                icon: const Icon(Icons.table_rows_outlined, size: 16),
                tooltip: l10n.diffSideBySide,
              ),
              ButtonSegment<DiffDisplayMode>(
                value: DiffDisplayMode.inline,
                label: isDesktop ? Text(l10n.diffInline) : null,
                icon: const Icon(Icons.view_headline_outlined, size: 16),
                tooltip: l10n.diffInline,
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selected) {
              setState(() {
                _userSelectedMode = selected.first;
              });
            },
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBySideView(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<SideBySideRow> rows,
  ) {
    final leftTitle = widget.oldTitle ?? l10n.conflictTheirVersion;
    final rightTitle = widget.newTitle ?? l10n.conflictYourVersion;
    final dividerColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.4,
    );

    return Column(
      children: [
        // Column Headers
        Container(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    leftTitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: dividerColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    rightTitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildSideCell(
                        context,
                        theme,
                        line: row.left,
                        isLeft: true,
                      ),
                    ),
                    Container(width: 1, color: dividerColor),
                    Expanded(
                      child: _buildSideCell(
                        context,
                        theme,
                        line: row.right,
                        isLeft: false,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSideCell(
    BuildContext context,
    ThemeData theme, {
    required DiffLine? line,
    required bool isLeft,
  }) {
    if (line == null) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(vertical: 2),
      );
    }

    Color? bg;
    if (line.kind == DiffKind.removed) {
      bg = Colors.red.withValues(alpha: 0.12);
    } else if (line.kind == DiffKind.added) {
      bg = Colors.green.withValues(alpha: 0.12);
    }

    final lineNum = isLeft ? line.aLine : line.bLine;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              lineNum?.toString() ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              line.text.isEmpty ? ' ' : line.text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineView(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<DiffLine> diffs,
  ) {
    return ListView.builder(
      itemCount: diffs.length,
      itemBuilder: (context, index) {
        final line = diffs[index];
        Color? bg;
        String marker = ' ';
        Color markerColor = theme.colorScheme.onSurfaceVariant;

        if (line.kind == DiffKind.removed) {
          bg = Colors.red.withValues(alpha: 0.12);
          marker = '-';
          markerColor = Colors.red.shade700;
        } else if (line.kind == DiffKind.added) {
          bg = Colors.green.withValues(alpha: 0.12);
          marker = '+';
          markerColor = Colors.green.shade700;
        }

        final lineNum = line.kind == DiffKind.removed ? line.aLine : line.bLine;

        return Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  lineNum?.toString() ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 14,
                child: Text(
                  marker,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: markerColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SelectableText(
                  line.text.isEmpty ? ' ' : line.text,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.4,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
