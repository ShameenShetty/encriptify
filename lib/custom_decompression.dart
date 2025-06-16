import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

Uint8List decompressChunk(Uint8List chunkData) {
  return ZLibDecoder().decodeBytes(chunkData);
}
