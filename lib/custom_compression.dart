import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

Future<Map<String, dynamic>> getHeaderInfo(String filePath) async {
  final file = File(filePath);
  final raf = await file.open();

  try {
    // Step 1: Read the first 4 bytes (Uint32) → header length
    final lengthBytes = await raf.read(4);
    if (lengthBytes.length < 4) {
      throw Exception('File too short to contain header length.');
    }
    final headerLength = ByteData.sublistView(lengthBytes).getUint32(0);

    // Step 2: Read the next `headerLength` bytes → header JSON
    final headerBytes = await raf.read(headerLength);
    final headerJson = utf8.decode(headerBytes);

    var t = jsonDecode(headerJson) as Map<String, dynamic>;
    print('Header json is $t');

    return jsonDecode(headerJson) as Map<String, dynamic>;
  } finally {
    await raf.close();
  }
}

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

  // Write to output file
  final outputBuilder = BytesBuilder();
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

Future<void> createEncryptedArchiveStreamed({
  required String inputFilePath,
  required String outputFilePath,
  required int numChunks,
}) async {
  final stopwatch = Stopwatch()..start();
  final inputFile = File(inputFilePath);
  final outputFile = File(outputFilePath);
  final inputLength = await inputFile.length();

  final chunkSize = (inputLength / numChunks).ceil();
  final chunkSizes = <int>[];

  final raf = await inputFile.open();
  final outputSink = outputFile.openWrite();

  try {
    // Placeholder for header (write 4 bytes + empty JSON temporarily)
    final dummyHeaderBytes = utf8.encode('{}');
    final dummyHeaderLen = ByteData(4)..setUint32(0, dummyHeaderBytes.length);
    outputSink.add(dummyHeaderLen.buffer.asUint8List());
    outputSink.add(dummyHeaderBytes);

    final compressedChunkOffsets =
        <int>[]; // optional: if you need seekable decompression
    final futures = <Future<Uint8List>>[];

    for (int i = 0; i < numChunks; i++) {
      final start = i * chunkSize;
      final end =
          (start + chunkSize > inputLength) ? inputLength : start + chunkSize;
      final length = end - start;

      await raf.setPosition(start);
      final chunk = await raf.read(length);

      // Compress using compute
      final compressedChunk = await compute(compressChunk, chunk);

      chunkSizes.add(compressedChunk.length);
      outputSink.add(compressedChunk); // Stream to output
    }

    await outputSink.flush();

    // Now create the real header
    final header = {
      "filename": p.basename(inputFilePath),
      "chunks": numChunks,
      "originalSize": inputLength,
      "chunkSizes": chunkSizes,
    };

    final headerJson = jsonEncode(header);
    final headerBytes = utf8.encode(headerJson);
    final headerLenBytes = ByteData(4)..setUint32(0, headerBytes.length);

    await outputSink.close();

    // Re-open output file and overwrite the dummy header
    final outputRaf = await outputFile.open(mode: FileMode.write);
    await outputRaf.setPosition(0);
    await outputRaf.writeFrom(headerLenBytes.buffer.asUint8List());
    await outputRaf.writeFrom(headerBytes);
    await outputRaf.close();

    stopwatch.stop();
    print('Created streamed encrypted archive: $outputFilePath');
    print('Time taken: ${stopwatch.elapsedMilliseconds / 1000} seconds');
  } finally {
    await raf.close();
    await outputSink.close();
  }
}

Uint8List decompressChunk(Uint8List chunkData) {
  return ZLibDecoder().decodeBytes(chunkData);
}

Future<void> decompressEncryptedArchive({
  required String inputFilePath,
  required String outputFilePath,
}) async {
  final file = File(inputFilePath);
  final raf = await file.open();

  try {
    // Step 1: Read the 4-byte header length
    final lengthBytes = await raf.read(4);
    final headerLength = ByteData.sublistView(lengthBytes).getUint32(0);

    // Step 2: Read the header JSON
    final headerBytes = await raf.read(headerLength);
    final header = jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;

    final chunkSizes = List<int>.from(header['chunkSizes']);
    final totalChunks = chunkSizes.length;

    final futures = <Future<Uint8List>>[];
    int offset = 4 + headerLength;

    // Step 3: For each chunk, read the bytes and decompress in parallel
    for (int i = 0; i < totalChunks; i++) {
      final chunkSize = chunkSizes[i];

      // Read this chunk
      await raf.setPosition(offset);
      final chunkBytes = await raf.read(chunkSize);

      // Decompress in isolate
      final future = compute(decompressChunk, chunkBytes);
      futures.add(future);

      offset += chunkSize;
    }

    // Step 4: Wait for all decompressed chunks
    final decompressedChunks = await Future.wait(futures);

    // Step 5: Combine and write output file
    final outputFile = File(outputFilePath);
    final sink = outputFile.openWrite();

    for (final chunk in decompressedChunks) {
      sink.add(chunk);
    }

    await sink.close();
    print('Decompression complete: $outputFilePath');
  } finally {
    await raf.close();
  }
}
