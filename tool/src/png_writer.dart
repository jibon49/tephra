// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var i = 0; i < 256; i++) {
    var c = i;
    for (var k = 0; k < 8; k++) {
      if ((c & 1) != 0) {
        c = (0xEDB88320 ^ (c >>> 1));
      } else {
        c = (c >>> 1);
      }
    }
    table[i] = c;
  }
  return table;
}();

int crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final byte in data) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >>> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

List<int> _chunk(String type, List<int> data) {
  final typeBytes = ascii.encode(type);
  final typeAndData = [...typeBytes, ...data];
  final crc = crc32(typeAndData);
  final length = data.length;

  return [
    (length >> 24) & 0xFF,
    (length >> 16) & 0xFF,
    (length >> 8) & 0xFF,
    length & 0xFF,
    ...typeBytes,
    ...data,
    (crc >> 24) & 0xFF,
    (crc >> 16) & 0xFF,
    (crc >> 8) & 0xFF,
    crc & 0xFF,
  ];
}

List<int> encodePng(int width, int height, List<int> rgb) {
  final out = BytesBuilder();
  // PNG signature
  out.add([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR chunk: width (4), height (4), depth=8 (1), colorType=2 (1), comp=0 (1), filter=0 (1), interlace=0 (1)
  final ihdr = [
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
    8,
    2,
    0,
    0,
    0,
  ];
  out.add(_chunk('IHDR', ihdr));

  // IDAT chunk: raw rows with filter byte 0
  final raw = BytesBuilder();
  final rowBytes = width * 3;
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter type: None
    final start = y * rowBytes;
    raw.add(rgb.sublist(start, start + rowBytes));
  }
  final compressed = ZLibEncoder().convert(raw.toBytes());
  out.add(_chunk('IDAT', compressed));

  // IEND chunk
  out.add(_chunk('IEND', []));

  return out.toBytes();
}

List<int> samplePngBytes() {
  const width = 64;
  const height = 48;
  final rgb = <int>[];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      rgb.add(194);
      rgb.add((65 + y * 3).clamp(0, 255));
      rgb.add((12 + x * 2).clamp(0, 255));
    }
  }
  return encodePng(width, height, rgb);
}
