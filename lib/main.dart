import 'dart:io';

import 'package:encriptify/custom_compression.dart';
import 'package:encriptify/custom_decompression.dart';
import 'package:encriptify/util/util.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Encryptify',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Encryptify Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int cpuCoreCount = 0;
  String resultText = '', timeTakenText = '';
  bool isLoading = false;

  @override
  void initState() {
    setState(() {
      cpuCoreCount = Platform.numberOfProcessors;
    });
    super.initState();
  }

  Future<void> pickAndCompressFile() async {
    // Step 1: Pick a file
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      String inputPath = result.files.single.path!;
      String fileName = result.files.single.name;

      // Step 2: Choose output path (e.g., same dir, new name)
      String outputZipPath = inputPath.replaceAll(RegExp(r'\.\w+$'), '.zip');
      String outputFilePath = inputPath.replaceAll(RegExp(r'\.\w+$'), '.encr');

      // TODO we should get the original file name from the header info and
      // set the output file name as that
      String outputDecryptedFilePath =
          inputPath.replaceAll(RegExp(r'\.\w+$'), '');

      setState(() {
        isLoading = true;
        resultText = '';
        timeTakenText = '';
      });

      // createEncryptedArchive(
      double timeTaken = await createEncryptedArchiveInChunks(
          inputFilePath: inputPath,
          outputFilePath: outputFilePath,
          numChunks: cpuCoreCount - 2);

      setState(() {
        resultText = 'Compressed input file "${inputPath.split('/').last}"';
        timeTakenText = 'It took $timeTaken seconds to compress file';
        isLoading = false;
      });

      // decompressFile(inputPath, inputPath.replaceAll(RegExp(r'\.\w+$'), ''));
      // compute(compressFileCompute, [inputPath, outputZipPath]);
      // compressFileStreamed(inputPath, outputZipPath);
      print('Starting compression');
      // print('Starting compression of file: $outputZipPath');
    } else {
      print('No file selected.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 10),
              Text('Num of available cores: $cpuCoreCount'),
              const SizedBox(height: 10),
              isLoading ? CircularProgressIndicator() : const SizedBox.shrink(),
              const SizedBox(height: 10),
              Text('Result: $resultText'),
              Text('Time Taken: $timeTakenText'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                      onPressed: () async {
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles();

                        if (result != null &&
                            result.files.single.path != null) {
                          String inputPath = result.files.single.path!;

                          var jsonHeader = await getHeaderInfo(inputPath);
                          print('Getting header information');
                          print('File json header is $jsonHeader');
                          // print('Starting compression of file: $outputZipPath');
                        } else {
                          print('No file selected.');
                        }
                      },
                      child: Text('isValidFile')),
                  const SizedBox(
                    width: 10,
                  ),
                  ElevatedButton(
                      onPressed: () async {
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles();

                        if (result != null &&
                            result.files.single.path != null) {
                          String inputPath = result.files.single.path!;

                          var headerInfo = await getHeaderInfo(inputPath);
                          String fileName = headerInfo['filename'];
                          String fileType = fileName.split('.').last;

                          String dir = p.dirname(inputPath);
                          String baseName = fileName;
                          print('dir - $dir, baseName - $baseName');
                          String outputPath =
                              p.join(dir, '${baseName}_decompressed.mp4');

                          print('Input path is "$inputPath"');
                          print('Filename is $fileName, fileType is $fileType');

                          print('Output path is $outputPath');

                          createDecompressedArchiveInChunks(
                            inputFilePath: inputPath,
                            outputFilePath: outputPath,
                          );
                        } else {
                          print('No file selected.');
                        }
                      },
                      child: Text('Decompress'))
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          pickAndCompressFile();
        },
        tooltip: 'Compress file',
        child: const Icon(Icons.add),
      ),
    );
  }
}
