// © 2026 Tephra. All rights reserved.

import 'package:test/test.dart';

import '../src/license_classifier.dart';

void main() {
  test('classifies MIT', () {
    const text = 'Permission is hereby granted, free of charge, to any person';
    expect(classifyLicenceText(text), LicenceKind.mit);
  });

  test('classifies BSD', () {
    const text =
        'Redistribution and use in source and binary forms, with or without';
    expect(classifyLicenceText(text), LicenceKind.bsd);
  });

  test('classifies Apache', () {
    const text = 'Apache License\nVersion 2.0, January 2004';
    expect(classifyLicenceText(text), LicenceKind.apache2);
  });

  test('classifies MPL', () {
    const text = 'Mozilla Public License Version 2.0';
    expect(classifyLicenceText(text), LicenceKind.mpl2);
  });

  test('classifies zlib', () {
    const text =
        "This software is provided 'as-is', without any express or implied warranty. "
        'Altered source versions must be plainly marked';
    expect(classifyLicenceText(text), LicenceKind.zlib);
  });

  test('classifies Unlicense', () {
    const text =
        'This is free and unencumbered software released into the public domain.';
    expect(classifyLicenceText(text), LicenceKind.unlicense);
  });

  test('GPL wins over MIT text', () {
    const text =
        'GNU GENERAL PUBLIC LICENSE ... Permission is hereby granted, free of charge';
    expect(classifyLicenceText(text), LicenceKind.gpl);
  });

  test('LGPL detected', () {
    const text = 'GNU Lesser General Public License';
    expect(classifyLicenceText(text), LicenceKind.lgpl);
  });

  test('AGPL detected', () {
    const text = 'GNU Affero General Public License';
    expect(classifyLicenceText(text), LicenceKind.agpl);
  });

  test('whitespace and case are normalised', () {
    const text = 'PERMISSION   is hereby\n granted, FREE of charge';
    expect(classifyLicenceText(text), LicenceKind.mit);
  });

  test('unknown text', () {
    const text = 'All rights reserved.';
    expect(classifyLicenceText(text), LicenceKind.unknown);
  });

  test('allowed flags', () {
    expect(LicenceKind.gpl.allowed, isFalse);
    expect(LicenceKind.flutterSdk.allowed, isTrue);
    expect(LicenceKind.missing.allowed, isFalse);
    expect(LicenceKind.mit.allowed, isTrue);
    expect(LicenceKind.bsd.allowed, isTrue);
    expect(LicenceKind.apache2.allowed, isTrue);
    expect(LicenceKind.mpl2.allowed, isTrue);
    expect(LicenceKind.zlib.allowed, isTrue);
    expect(LicenceKind.unlicense.allowed, isTrue);
  });
}
