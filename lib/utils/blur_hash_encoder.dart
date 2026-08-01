import 'dart:io';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Encodes a BlurHash from image file bytes on a background isolate.
Future<String?> encodeBlurHashFromFile(File file) async {
  try {
    final bytes = await file.readAsBytes();
    return compute(_encodeBlurHashIsolate, bytes);
  } catch (e) {
    debugPrint('BlurHash encode failed: $e');
    return null;
  }
}

/// Encodes a BlurHash from already-loaded bytes on a background isolate.
Future<String?> encodeBlurHashFromBytes(Uint8List bytes) async {
  try {
    return compute(_encodeBlurHashIsolate, bytes);
  } catch (e) {
    debugPrint('BlurHash encode failed: $e');
    return null;
  }
}

String? _encodeBlurHashIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // Downscale for fast encode; component count matches API backfill plan (4x3).
  final resized = img.copyResize(
    decoded,
    width: 32,
    interpolation: img.Interpolation.average,
  );
  final hash = BlurHash.encode(resized, numCompX: 4, numCompY: 3);
  return hash.hash;
}
