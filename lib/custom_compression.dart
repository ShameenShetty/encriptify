import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// This runs in an isolate for compression
Uint8List compressChunk(Uint8List data) {
  return ZLibEncoder().encode(data) as Uint8List;
}

Future<void> createEncryptedArchive({
  required String inputFilePath,
  required String outputFilePath,
  required int numChunks,
}) async {
  final stopwatch = Stopwatch()..start();

  final inputFile = File(inputFilePath);
  final fileBytes = await inputFile.readAsBytes();
  final fileSize = fileBytes.length;

  final chunkSize = (fileSize / numChunks).ceil();
  final List<Future<Uint8List>> compressionFutures = [];
  final List<int> chunkSizes = [];

  for (int i = 0; i < numChunks; i++) {
    final start = i * chunkSize;
    final end = (start + chunkSize > fileSize) ? fileSize : start + chunkSize;
    final chunk = fileBytes.sublist(start, end);

    // Launch compression in parallel
    compressionFutures.add(compute(compressChunk, chunk));
  }

  // Wait for all compressions to finish
  final List<Uint8List> compressedChunks =
      await Future.wait(compressionFutures);

  // Record compressed chunk sizes
  for (var chunk in compressedChunks) {
    chunkSizes.add(chunk.length);
  }

  // Header info
  final headerMap = {
    "filename": p.basename(inputFilePath),
    "chunks": numChunks,
    "originalSize": fileSize,
    "chunkSizes": chunkSizes,
  };
  final headerJson = jsonEncode(headerMap);
  final headerBytes = utf8.encode(headerJson);
  final headerLengthBytes = ByteData(4)..setUint32(0, headerBytes.length);

  final magicBytes = utf8.encode("ENCR"); // [0x45, 0x4E, 0x43, 0x52] file sign
  final versionBytes = Uint8List(2)
    ..[0] = 0
    ..[1] = 1; // version 1

  // Write to output file
  final outputBuilder = BytesBuilder();
  outputBuilder.add(magicBytes);
  outputBuilder.add(versionBytes);
  outputBuilder.add(headerLengthBytes.buffer.asUint8List());
  outputBuilder.add(headerBytes);
  for (var chunk in compressedChunks) {
    outputBuilder.add(chunk);
  }

  await File(outputFilePath).writeAsBytes(outputBuilder.takeBytes());

  stopwatch.stop();
  print('Compressed encrypted archive: $outputFilePath');
  print('Time taken: ${stopwatch.elapsedMilliseconds / 1000} seconds');
}
