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

Stream<Uint8List> chunkedStream(Stream<List<int>> input, int chunkSize) async* {
  final buffer = BytesBuilder();
  await for (final data in input) {
    buffer.add(data);
    while (buffer.length >= chunkSize) {
      final chunk = buffer.takeBytes();
      yield Uint8List.fromList(chunk.sublist(0, chunkSize));
      buffer.add(chunk.sublist(chunkSize)); // push remainder back into buffer
    }
  }

  if (buffer.length > 0) {
    yield buffer.takeBytes(); // yield any remaining data
  }
}

Future<void> createEncryptedArchiveInChunks({
  required String inputFilePath,
  required String outputFilePath,
  required int numChunks,
  int chunkLoadSize = 300 * 1024 * 1024, // 300 MB default chunk
}) async {
  final stopwatch = Stopwatch()..start();

  final inputFile = File(inputFilePath);
  final fileLength = await inputFile.length();
  final inputStream = inputFile.openRead();

  final chunkSizes = <int>[];
  final outputSink = File(outputFilePath).openWrite();

  // Placeholder: write header later
  final magicBytes = utf8.encode("ENCR");
  final versionBytes = Uint8List(2)
    ..[0] = 0
    ..[1] = 1;
  final placeholderHeader = Uint8List(4 + 1024); // Reserve 1 KB header space
  outputSink.add(magicBytes);
  outputSink.add(versionBytes);
  outputSink.add(placeholderHeader);

  int totalSizeRead = 0;
  int chunkIndex = 0;
  int numMainChunks = (fileLength / chunkLoadSize).ceil();

  int pos = 0;
  await for (final chunk in chunkedStream(inputStream, chunkLoadSize)) {
    final subChunkSize =
        (chunk.length / numChunks).ceil(); // ✅ Now chunk is Uint8List

    // print('sub chunk size is $subChunkSize');
    print('');
    print(
        "Compressing main chunk ${pos + 1}/$numMainChunks of size: $subChunkSize");

    final List<Future<Uint8List>> futures = [];

    for (int i = 0; i < numChunks; i++) {
      final start = i * subChunkSize;
      final end = (start + subChunkSize > chunk.length)
          ? chunk.length
          : start + subChunkSize;
      if (start >= chunk.length) break;
      final subChunk = Uint8List.fromList(chunk.sublist(start, end));
      print("Compressing sub chunk ${i + 1}/$numChunks");

      futures.add(compute(compressChunk, subChunk));
    }

    final compressedChunks = await Future.wait(futures);
    for (final compressed in compressedChunks) {
      chunkSizes.add(compressed.length);
      outputSink.add(compressed);
    }
    pos++;
  }

  await outputSink.flush();
  await outputSink.close();

  // Write actual header now
  final headerMap = {
    "filename": p.basename(inputFilePath),
    "chunks": chunkSizes.length,
    "originalSize": fileLength,
    "chunkSizes": chunkSizes,
  };
  final headerJson = jsonEncode(headerMap);
  final headerBytes = utf8.encode(headerJson);
  final headerLengthBytes = ByteData(4)..setUint32(0, headerBytes.length);

  final finalHeader = BytesBuilder();
  finalHeader.add(headerLengthBytes.buffer.asUint8List());
  finalHeader.add(headerBytes);

  final raf = await File(outputFilePath).open(mode: FileMode.writeOnlyAppend);
  await raf.setPosition(magicBytes.length + versionBytes.length);
  await raf.writeFrom(finalHeader.takeBytes());
  await raf.close();

  stopwatch.stop();
  print('Compressed encrypted archive: $outputFilePath');
  print('Time taken: ${stopwatch.elapsedMilliseconds / 1000} seconds');
}
