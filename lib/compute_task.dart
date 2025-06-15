import 'dart:async';

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

int countNumPrimesInRange(int end) {
  int numPrimes = 0;
  for (int i = 2; i <= end; i++) {
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

  print('Starting completer');
  final Completer<int> completer = Completer();
  completer.complete(getNumPrimesCompute(end));
  print('Finished completer');

  for (int i = 1; i < numTasks + 1; i++) {
    int chunkSize = (end / numTasks).floor();
    int chunkEnd = i * chunkSize;
    print('starting from $start to end at $chunkEnd');
    start = chunkEnd;
  }

  return await 10;
  // return await compute(countNumPrimesInRange, end);
}

Future<int> getNumPrimesCompute(int end) async {
  return await compute(countNumPrimesInRange, end);
}
