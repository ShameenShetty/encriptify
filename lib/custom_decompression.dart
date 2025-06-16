import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:encriptify/util/util.dart';
import 'package:flutter/foundation.dart';

Uint8List decompressChunk(Uint8List chunkData) {
  return ZLibDecoder().decodeBytes(chunkData);
}

Future<void> createDecompressedArchiveInChunks({
  required String inputFilePath,
  required String outputFilePath,
}) async {
  final stopwatch = Stopwatch()..start();

  // Step 1: Validate file
  final isValid = await isValidEncrFile(inputFilePath);
  if (!isValid) {
    throw Exception("Invalid ENCR file");
  }

  // Step 2: Parse header
  final header = await getHeaderInfo(inputFilePath);
  final totalChunks = header['chunks'] as int;
  final chunkSizes = List<int>.from(header['chunkSizes']);
  final headerSize = 4 + utf8.encode(jsonEncode(header)).length;

  final file = File(inputFilePath);
  final raf = await file.open();
  final outFile = File(outputFilePath).openWrite();

  // Skip past magic (4), version (2), header length (4), header JSON
  int offset = 4 + 2 + headerSize;

  final cpuCores = Platform.numberOfProcessors;
  final parallelism = cpuCores > 2 ? cpuCores - 2 : 1;

  int chunkIndex = 0;
  while (chunkIndex < totalChunks) {
    // Determine how many chunks to process in this batch
    final remaining = totalChunks - chunkIndex;
    final currentBatchSize = remaining < parallelism ? remaining : parallelism;

    final futures = <Future<Uint8List>>[];
    final chunkDataList = <Uint8List>[];

    for (int i = 0; i < currentBatchSize; i++) {
      final chunkSize = chunkSizes[chunkIndex + i];
      await raf.setPosition(offset);
      final chunkData = await raf.read(chunkSize);
      offset += chunkSize;
      chunkDataList.add(chunkData);
    }

    // Decompress in parallel
    for (final compressed in chunkDataList) {
      futures.add(compute(decompressChunk, compressed));
    }

    final decompressedChunks = await Future.wait(futures);
    for (final chunk in decompressedChunks) {
      outFile.add(chunk);
    }

    chunkIndex += currentBatchSize;
  }

  await raf.close();
  await outFile.flush();
  await outFile.close();

  stopwatch.stop();
  print('Decompressed file written to $outputFilePath');
  print('Time taken: ${stopwatch.elapsedMilliseconds / 1000} seconds');
}
