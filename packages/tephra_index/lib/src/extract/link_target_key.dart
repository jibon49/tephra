// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Key used to find links whose resolution may change when a file named like [targetRaw] appears or disappears.
/// Last path segment, lower-case, with a trailing '.md' removed. '' for same-note links.
String linkTargetKey(String targetRaw) {
  var t = targetRaw.replaceAll(r'\', '/').trim();
  while (t.endsWith('/')) {
    t = t.substring(0, t.length - 1);
  }
  if (t.isEmpty) return '';
  final lastSlash = t.lastIndexOf('/');
  var seg = lastSlash != -1 ? t.substring(lastSlash + 1) : t;
  seg = seg.toLowerCase();
  if (seg.endsWith('.md')) {
    seg = seg.substring(0, seg.length - 3);
  }
  return seg;
}

/// Keys a file contributes: notes → {stemKey}; other files → {nameKey}.
/// ('Folder/Note.md' → {'note'}; 'img/a.png' → {'a.png'})
Set<String> fileTargetKeys(VaultPath path) {
  if (path.extension.toLowerCase() == 'md') {
    return {path.stem.toLowerCase()};
  }
  return {path.name.toLowerCase()};
}
