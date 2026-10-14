// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

enum ViewKind { markdown, canvas, base, pdf, image, audio, video, unsupported }

const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'};
const audioExtensions = {
  'mp3',
  'wav',
  'm4a',
  'ogg',
  'flac',
  '3gp',
  'aac',
  'opus',
};
const videoExtensions = {'mp4', 'webm', 'mov', 'mkv', 'ogv'};

ViewKind viewKindFor(VaultPath path) {
  final ext = path.extension.toLowerCase();
  switch (ext) {
    case 'md':
      return ViewKind.markdown;
    case 'canvas':
      return ViewKind.canvas;
    case 'base':
      return ViewKind.base;
    case 'pdf':
      return ViewKind.pdf;
    default:
      if (imageExtensions.contains(ext)) return ViewKind.image;
      if (audioExtensions.contains(ext)) return ViewKind.audio;
      if (videoExtensions.contains(ext)) return ViewKind.video;
      return ViewKind.unsupported;
  }
}
