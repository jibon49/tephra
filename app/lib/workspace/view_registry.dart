// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'note_view.dart';
import 'tab_content.dart';
import 'unsupported_file_view.dart';

typedef TabViewBuilder = Widget Function(
  BuildContext context,
  WidgetRef ref,
  TabContent content,
  String tabId,
);

final class ViewRegistration {
  const ViewRegistration({
    required this.id,
    required this.extensions,
    required this.builder,
    this.title,
    required this.icon,
  });

  final String id;
  final Set<String> extensions;
  final TabViewBuilder builder;
  final String Function(TabContent, AppLocalizations)? title;
  final IconData icon;
}

final class ViewRegistry {
  final Map<String, ViewRegistration> _byExtension = {};
  final Map<String, ViewRegistration> _byId = {};

  void register(ViewRegistration r) {
    _byId[r.id] = r;
    for (final ext in r.extensions) {
      _byExtension[ext.toLowerCase()] = r;
    }
  }

  ViewRegistration? registrationFor(TabContent content) {
    if (content is FileTabContent) {
      final ext = content.path.extension.toLowerCase();
      return _byExtension[ext];
    }
    return null;
  }

  Widget build(
    BuildContext context,
    WidgetRef ref,
    TabContent content,
    String tabId,
  ) {
    final reg = registrationFor(content);
    if (reg != null) {
      return reg.builder(context, ref, content, tabId);
    }
    return UnsupportedFileView(content: content, tabId: tabId);
  }

  String titleFor(TabContent content, AppLocalizations l10n) {
    final reg = registrationFor(content);
    if (reg?.title != null) {
      return reg!.title!(content, l10n);
    }
    if (content is FileTabContent) {
      if (content.path.isMarkdown) {
        return content.path.stem;
      }
      return content.path.name;
    }
    return '';
  }

  IconData iconFor(TabContent content) {
    final reg = registrationFor(content);
    return reg?.icon ?? Icons.insert_drive_file_outlined;
  }
}

final markdownRegistration = ViewRegistration(
  id: 'markdown',
  extensions: const {'md'},
  builder: (context, ref, content, tabId) {
    final file = content as FileTabContent;
    return NoteView(path: file.path, subpath: file.subpath, tabId: tabId);
  },
  icon: Icons.description_outlined,
);

final viewRegistryProvider = Provider<ViewRegistry>((ref) {
  final r = ViewRegistry();
  r.register(markdownRegistration);
  return r;
});
