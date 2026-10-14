// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../l10n/app_localizations.dart';
import '../search/query_block_view.dart';
import 'reading_scope.dart';

/// Syntax highlighter wrapping `re_highlight`.
final class CodeHighlighter {
  CodeHighlighter._();
  static final CodeHighlighter instance = CodeHighlighter._();

  static final _logger = Logger('code_highlighter');

  Highlight? _highlight;
  Highlight get highlight {
    return _highlight ??= () {
      final hl = Highlight();
      hl.registerLanguages(builtinAllLanguages);
      return hl;
    }();
  }

  static const _aliases = {
    'js': 'javascript',
    'jsx': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'rb': 'ruby',
    'sh': 'bash',
    'shell': 'bash',
    'zsh': 'bash',
    'yml': 'yaml',
    'md': 'markdown',
    'c++': 'cpp',
    'cs': 'csharp',
    'ps1': 'powershell',
    'kt': 'kotlin',
    'rs': 'rust',
    'golang': 'go',
    'html': 'xml',
    'vue': 'xml',
    'svg': 'xml',
  };

  static const _specialLanguages = {'mermaid', 'query', 'base'};

  bool isSpecialLanguage(String? lang) {
    if (lang == null) return false;
    return _specialLanguages.contains(lang.trim().toLowerCase());
  }

  String? languageId(String? lang) {
    if (lang == null) return null;
    final lower = lang.trim().toLowerCase();
    if (lower.isEmpty || _specialLanguages.contains(lower)) return null;
    final mapped = _aliases[lower] ?? lower;
    if (builtinAllLanguages.containsKey(mapped)) {
      return mapped;
    }
    return null;
  }

  TextSpan highlightCode({
    required String code,
    required String? lang,
    required ThemeData theme,
    TextStyle? baseStyle,
  }) {
    final style =
        baseStyle ??
        TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const [
            'Consolas',
            'Cascadia Mono',
            'Roboto Mono',
          ],
          color: theme.colorScheme.onSurface,
        );

    if (code.length > 20000 || lang == null || isSpecialLanguage(lang)) {
      return TextSpan(text: code, style: style);
    }

    final id = languageId(lang);
    if (id == null) {
      return TextSpan(text: code, style: style);
    }

    try {
      final result = highlight.highlight(code: code, language: id);
      final themeMap = theme.brightness == Brightness.dark
          ? atomOneDarkTheme
          : atomOneLightTheme;
      final renderer = TextSpanRenderer(style, themeMap);
      result.render(renderer);
      return renderer.span ?? TextSpan(text: code, style: style);
    } catch (e, st) {
      _logger.warning('Failed to highlight code for language $lang', e, st);
      return TextSpan(text: code, style: style);
    }
  }
}

/// Renders a Markdown fenced code block with optional syntax highlighting and copy button.
class CodeBlockView extends StatelessWidget {
  const CodeBlockView({super.key, required this.node});

  final MdCodeBlock node;

  @override
  Widget build(BuildContext context) {
    if (node.language == 'query') {
      return QueryBlockView(query: node.code);
    }

    final scope = ReadingScope.maybeOf(context);
    final theme = Theme.of(context);
    final styles = scope?.styles;
    final l10n = AppLocalizations.of(context);

    final lang = node.language;
    final isSpecial = CodeHighlighter.instance.isSpecialLanguage(lang);

    final span = CodeHighlighter.instance.highlightCode(
      code: node.code,
      lang: lang,
      theme: theme,
      baseStyle: styles?.mono,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            styles?.codeBackground ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (lang != null) ...[
                Text(
                  lang,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isSpecial) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.codeRenderedLater,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: 'Copy',
                onPressed: () async {
                  final textToCopy = node.code.endsWith('\n')
                      ? node.code.substring(0, node.code.length - 1)
                      : node.code;
                  await Clipboard.setData(ClipboardData(text: textToCopy));
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(
                      context,
                    )?.showSnackBar(SnackBar(content: Text(l10n.codeCopied)));
                  }
                },
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text.rich(span, softWrap: false, style: styles?.mono),
          ),
        ],
      ),
    );
  }
}
