import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'dart:core';

int get4ThPowerSum(int n) {
  int sum = 0;
  for (int i = 1; i <= n; i++) {
    sum += i * i * i * i;
  }

  return sum;
}

Future<int> getComputeSum(int end) async {
  return await compute(get4ThPowerSum, end);
}

int countNumPrimesInRange(List<int> range) {
  int numPrimes = 0;
  int start = range.first;
  int end = range.last;

  for (int i = start; i <= end; i++) {
    if (isPrime(i)) numPrimes++;
  }

  return numPrimes;
}

bool isPrime(int n) {
  if (n <= 1) return false;
  if (n == 2) return true;
  if (n % 2 == 0) return false;

  for (int i = 3; i * i <= n; i += 2) {
    if (n % i == 0) return false;
  }

  return true;
}

Future<int> getNumPrimesInParallelCompute(int end, int numTasks) async {
  // -> 1000 / 3 - [0, 333], [334, 666], [667, 1000]
  int start = 0;

  List<Future<int>> futuresList = [];

  for (int i = 1; i < numTasks + 1; i++) {
    int chunkSize = (end / numTasks).floor();
    int chunkEnd = i * chunkSize;
    var msg = [start, chunkEnd];
    // print('Task $i is $msg');

    Future<int> futureTask = getNumPrimesParallelCompute(msg);
    futuresList.add(futureTask);

    start = chunkEnd;
  }

  // print(
  //     'End of generating parallel tasks, num of tasks running in parallel is ${futuresList.length}');

  int sum = 0;
  List<int> resultList = await Future.wait(futuresList);
  sum = resultList.reduce((a, b) => a + b);

  // print('Total sum is $sum');
  return sum;
}

Future<int> getNumPrimesCompute(List<int> msg) async {
  return await compute(countNumPrimesInRange, msg);
}

Future<int> getNumPrimesParallelCompute(List<int> msg) async {
  // print('Running task in range $msg');
  return await compute(countNumPrimesInRange, msg);
}
