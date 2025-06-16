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
    if (isValidFile) {
      print('It is a valid encr file');
      // Step 1: Read the first 4 bytes (Uint32) → header length
      final lengthBytes = await raf.read(4);
      if (lengthBytes.length < 4) {
        throw Exception('File too short to contain header length.');
      }
      final headerLength = ByteData.sublistView(lengthBytes).getUint32(0);

      // Step 2: Read the next `headerLength` bytes → header JSON
      final headerBytes = await raf.read(headerLength);
      print('Header bytes are $headerBytes');
      final headerJson = utf8.decode(headerBytes);

      var jsonHeader = jsonDecode(headerJson) as Map<String, dynamic>;
      print('Header json is $jsonHeader');

      return jsonHeader;
    } else {
      print('It is not a ENCR file');
      return {};
    }
  } finally {
    await raf.close();
  }
}
