import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

Future<bool> isValidEncrFile(String filePath) async {
  final file = File(filePath);
  final raf = await file.open();
  final magicBytes = await raf.read(4);
  await raf.close();

  // Check if bytes match 'ENCR'
  return magicBytes.length == 4 &&
      magicBytes[0] == 0x45 && // E
      magicBytes[1] == 0x4E && // N
      magicBytes[2] == 0x43 && // C
      magicBytes[3] == 0x52; // R
}

Future<Map<String, dynamic>> getHeaderInfo(String filePath) async {
  final file = File(filePath);
  final raf = await file.open();

  try {
    // Step 0: Check if it is a valid encr file first
    bool isValidFile = await isValidEncrFile(filePath);
    if (!isValidFile) {
      print('It is not a ENCR file');
      return {};
    }

    print('It is a valid encr file');
    print('Retrieving file information...');

    // Step 1: Skip magic (4 bytes) + version (2 bytes) → position = 6
    await raf.setPosition(6);

    // Step 2: Read the next 4 bytes (header length)
    final lengthBytes = await raf.read(4);
    if (lengthBytes.length < 4) {
      throw Exception('File too short to contain header length.');
    }
    final headerLength = ByteData.sublistView(lengthBytes).getUint32(0);

    // Step 3: Read the actual header JSON bytes
    final headerBytes = await raf.read(headerLength);
    // print('Header bytes are $headerBytes');
    final headerJson = utf8.decode(headerBytes);

    var jsonHeader = jsonDecode(headerJson) as Map<String, dynamic>;
    print('Header json is $jsonHeader');

    return jsonHeader;
  } finally {
    await raf.close();
  }
}

String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes < 1024) return '$bytes B';
  const suffixes = ['KB', 'MB', 'GB', 'TB', 'PB', 'EB'];
  int i = -1;
  double size = bytes.toDouble();

  do {
    size /= 1024;
    i++;
  } while (size >= 1024 && i < suffixes.length - 1);

  return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
}
