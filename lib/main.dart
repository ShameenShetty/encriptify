import 'dart:io';

import 'package:encriptify/compute_task.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // runHeavyTask(90000000);
          setState(() {
            isLoading = true;
          });

          Stopwatch stopwatch = Stopwatch()..start();
          // int result = await compute(runHeavyTaskIsolate, 9000000);
          int end = 900000;
          getNumPrimesInParallelCompute(end, 3);
          int result = await getNumPrimesCompute(end);
          stopwatch.stop();
          double timeTaken = stopwatch.elapsedMilliseconds / 1000;

          setState(() {
            isLoading = false;
            resultText = 'There are $result prime numbers from 1 to $end';
            timeTakenText = 'It took $timeTaken seconds to calculate task';
          });
        },
        tooltip: 'Run heavy task',
        child: const Icon(Icons.add),
      ),
    );
  }
}
