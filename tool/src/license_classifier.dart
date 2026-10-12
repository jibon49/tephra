// © 2026 Tephra. All rights reserved.

enum LicenceKind {
  mit,
  bsd,
  apache2,
  mpl2,
  zlib,
  unlicense,
  flutterSdk,
  gpl,
  lgpl,
  agpl,
  unknown,
  missing,
}

extension LicenceKindInfo on LicenceKind {
  bool get allowed {
    switch (this) {
      case LicenceKind.mit:
      case LicenceKind.bsd:
      case LicenceKind.apache2:
      case LicenceKind.mpl2:
      case LicenceKind.zlib:
      case LicenceKind.unlicense:
      case LicenceKind.flutterSdk:
        return true;
      case LicenceKind.gpl:
      case LicenceKind.lgpl:
      case LicenceKind.agpl:
      case LicenceKind.unknown:
      case LicenceKind.missing:
        return false;
    }
  }

  String get label {
    switch (this) {
      case LicenceKind.mit:
        return 'MIT';
      case LicenceKind.bsd:
        return 'BSD';
      case LicenceKind.apache2:
        return 'Apache-2.0';
      case LicenceKind.mpl2:
        return 'MPL-2.0';
      case LicenceKind.zlib:
        return 'zlib';
      case LicenceKind.unlicense:
        return 'Unlicense';
      case LicenceKind.flutterSdk:
        return 'BSD-3-Clause (Flutter SDK)';
      case LicenceKind.gpl:
        return 'GPL';
      case LicenceKind.lgpl:
        return 'LGPL';
      case LicenceKind.agpl:
        return 'AGPL';
      case LicenceKind.unknown:
        return 'Unknown';
      case LicenceKind.missing:
        return 'Missing';
    }
  }
}

LicenceKind classifyLicenceText(String text) {
  final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.contains('mozilla public license')) {
    return LicenceKind.mpl2;
  }
  if (normalized.contains('gnu affero general public license')) {
    return LicenceKind.agpl;
  }
  if (normalized.contains('gnu lesser general public license') ||
      normalized.contains('gnu library general public license')) {
    return LicenceKind.lgpl;
  }
  if (normalized.contains('gnu general public license')) {
    return LicenceKind.gpl;
  }
  if (normalized.contains('apache license') &&
      normalized.contains('version 2.0')) {
    return LicenceKind.apache2;
  }
  if (normalized.contains('permission is hereby granted, free of charge')) {
    return LicenceKind.mit;
  }
  if (normalized.contains(
    'redistribution and use in source and binary forms',
  )) {
    return LicenceKind.bsd;
  }
  if (normalized.contains(
        "this software is provided 'as-is', without any express or implied warranty",
      ) &&
      normalized.contains('altered source versions must be plainly marked')) {
    return LicenceKind.zlib;
  }
  if (normalized.contains(
    'this is free and unencumbered software released into the public domain',
  )) {
    return LicenceKind.unlicense;
  }
  return LicenceKind.unknown;
}
