import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ArtworkCache {
  const ArtworkCache({
    this.maxBytes = 12 * 1024 * 1024,
    this.maxCacheBytes = 512 * 1024 * 1024,
    this.directoryPath,
  });

  final int maxBytes;
  final int maxCacheBytes;
  final String? directoryPath;

  Future<String?> store({
    required String songId,
    required int modifiedAtMillis,
    required Uint8List? bytes,
    required String? mimeType,
  }) async {
    if (bytes == null || bytes.isEmpty || bytes.length > maxBytes) return null;
    final extension = _safeExtension(bytes, mimeType);
    if (extension == null) return null;

    final directory = await _directory();
    await directory.create(recursive: true);
    final name = '${_stableHash('$songId:$modifiedAtMillis')}.$extension';
    final destination = File(p.join(directory.path, name));
    if (await destination.exists() &&
        await destination.length() == bytes.length) {
      return destination.path;
    }
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
    return destination.path;
  }

  Future<void> prune() async {
    final directory = await _directory();
    if (!await directory.exists()) return;
    final files = <File>[];
    var totalBytes = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || p.extension(entity.path) == '.tmp') continue;
      try {
        totalBytes += await entity.length();
        files.add(entity);
      } on FileSystemException {
        // A concurrently removed cache entry needs no further attention.
      }
    }
    if (totalBytes <= maxCacheBytes) return;
    final ordered = <({File file, DateTime touched, int size})>[];
    for (final file in files) {
      try {
        ordered.add((
          file: file,
          touched: (await file.stat()).modified,
          size: await file.length(),
        ));
      } on FileSystemException {
        // Another scan may have invalidated the item.
      }
    }
    ordered.sort((a, b) => a.touched.compareTo(b.touched));
    for (final item in ordered) {
      if (totalBytes <= maxCacheBytes) break;
      try {
        await item.file.delete();
        totalBytes -= item.size;
      } on FileSystemException {
        // Ignore races with other cache operations.
      }
    }
  }

  Future<Directory> _directory() async {
    if (directoryPath case final path?) return Directory(path);
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'Cadence', 'Artwork'));
  }

  static String? _safeExtension(Uint8List bytes, String? mimeType) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'jpg';
    }
    if (bytes.length >= 6) {
      final header = String.fromCharCodes(bytes.take(6));
      if (header == 'GIF87a' || header == 'GIF89a') return 'gif';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'webp';
    }
    if (mimeType == 'image/bmp' &&
        bytes.length >= 2 &&
        bytes[0] == 0x42 &&
        bytes[1] == 0x4d) {
      return 'bmp';
    }
    return null;
  }

  static String _stableHash(String value) {
    var hash = 0xcbf29ce484222325;
    for (final byte in value.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
