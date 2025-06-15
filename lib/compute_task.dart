import 'dart:core';

import 'package:flutter/foundation.dart';

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
  print('Running task in range $msg, weight is ${getWeight(msg)}');
  return await compute(countNumPrimesInRange, msg);
}

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
int getWeight(List<int> range) {
  int weight = 0;

  int start = range[0];
  int end = range[1];

  for (int i = start; i <= end; i++) {
    weight += i;
  }

  return weight;
}
