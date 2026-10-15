import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// One photo in the sizes the apps show (D-008): WebP `thumb` (160 px), `medium` (480 px)
/// and `large` (1080 px) on the short side, plus the original JPEG.
typedef MediaVariants = ({Uint8List thumb, Uint8List medium, Uint8List large, Uint8List orig});

abstract final class Media {
  /// Makes the sizes from a JPEG taken with [Photos.pick] (already at most 1600 px), on
  /// the phone: server-side resizing needs a paid plan, and small files upload faster.
  static Future<MediaVariants> variants(Uint8List jpeg) async {
    Future<Uint8List> webp(int px, int quality) => FlutterImageCompress.compressWithList(
      jpeg,
      minWidth: px,
      minHeight: px,
      quality: quality,
      format: CompressFormat.webp,
    );
    return (
      thumb: await webp(160, 70),
      medium: await webp(480, 75),
      large: await webp(1080, 80),
      orig: jpeg,
    );
  }

  /// Keeps a photo on the phone until the outbox has uploaded it; returns its path.
  static Future<String> keep(Uint8List bytes, String name) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/pending-photos');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// A kept photo, or null once it is gone.
  static Future<Uint8List?> read(String path) async {
    final file = File(path);
    return await file.exists() ? file.readAsBytes() : null;
  }

  static Future<void> forget(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
