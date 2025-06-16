import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// If we splitting numbers from 1 to 9 into 3 buckets it becomes
/// Bucket 1 - 1, 2, 3 → the sum is 6
/// Bucket 2 - 4, 5, 6 the sum is 15
/// Bucket 3 - 7, 8, 9 the sum is 24
///
///
/// Meaning for a very large range we get an issue where one mini-task completes
/// very quickly and the mini-tasks near the end of the range will take twice
/// as long
/// One way we can normalize the 'weight' of the mini-task i.e the amount of
/// work is it have a pool and each Isolate takes a chunk from it, once they
/// are completed with their chunk they take the next chunk from the pool - i.e
/// dynamic task scheduling
///
/// Another thing we can do is to generalize the concepts of a 'weight' of a
/// task and split the workload based on the weights.
/// In the 3 buckets given above B2 weight is 2.5x as much as B1, and B3 is 4x
/// as much
/// We can distribute the numbers in the buckets to normalize the weights
/// Bucket 1: 1, 8, 9 → the sum is 18
/// Bucket 2: 2, 6, 10 → the sum is 18
/// Bucket 3: 3, 4, 5 → the sum is 12
///
/// Meaning for other tasks, lets say compressing subfolders, if we had 4 tasks
/// and 12 folders, we could just divide into sets of 3 folders each but we get
/// the issue where one set of folders might take much longer to compress
/// meaning even if we using multiple cores we aren't getting the full benefit
/// If we decided that the 'weight' of the task is the size of the folder then
/// we can normalize the distribution and get the benefits of parallelism
///
/// Dividing a dataset into smaller sets gives us the same issue, we need to
/// decide what the weight of the smaller subsets are and normalize them
int getWeight(List<int> range) {
  int weight = 0;

  int start = range[0];
  int end = range[1];

  for (int i = start; i <= end; i++) {
    weight += i;
  }

  return weight;
}

Future<void> compressFileStreamed(
    String inputFilePath, String outputZipPath) async {
  final stopwatch = Stopwatch()..start();

  final encoder = ZipFileEncoder();

  // Create the zip file (this opens a file stream internally)
  encoder.create(outputZipPath);

  // Add the file to the archive
  encoder.addFile(File(inputFilePath));

  // Close the encoder (very important)
  encoder.close();

  stopwatch.stop();
  print('Compressed to $outputZipPath');
  print('Time taken: ${stopwatch.elapsedMilliseconds / 1000} seconds');
}

Future<void> compressFile(String inputFilePath, String outputZipPath) async {
  // Read file bytes
  File inputFile = File(inputFilePath);

  Stopwatch compressionWatch = Stopwatch()..start;
  final bytes = await inputFile.readAsBytes();

  // Create a new archive
  final archive = Archive();

  // Add file to archive
  archive.addFile(ArchiveFile(
    p.basename(inputFile.path),
    bytes.length,
    bytes,
  ));

  // Encode the archive
  final zipData =
      ZipEncoder().encode(archive, level: DeflateLevel.bestCompression);

  if (zipData == null) {
    print('Failed to encode archive');
    return;
  }

  // Write to zip file
  final outputFile = File(outputZipPath);
  await outputFile.writeAsBytes(zipData);

  print('Compression complete: $outputZipPath');
  compressionWatch.stop();
  print(
      'Time taken to compress file is ${compressionWatch.elapsedMilliseconds / 1000} seconds');
}

Future<void> decompressFile(String inputZipPath, String outputDirPath) async {
  final inputStream = InputFileStream(inputZipPath);

  // Decode the archive from the input stream
  final archive = ZipDecoder().decodeStream(inputStream);

  for (final file in archive) {
    final filePath = p.join(outputDirPath, file.name);

    if (file.isFile) {
      final outFile = File(filePath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    } else {
      final dir = Directory(filePath);
      await dir.create(recursive: true);
    }
  }

  await inputStream.close();
  print('Decompression complete: $outputDirPath');
}

void compressFileCompute(List<String> args) async {
  print('Starting compress file compute');
  Stopwatch compressionWatch = Stopwatch()..start;
  String inputPath = args.first;
  String outputZipPath = args.last;

  compressFile(inputPath, outputZipPath);
  compressionWatch.stop();
  print(
      'Time taken to compress file is ${compressionWatch.elapsedMilliseconds / 1000} seconds');
}
