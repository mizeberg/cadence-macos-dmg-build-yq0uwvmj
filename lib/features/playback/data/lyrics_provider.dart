import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../library/domain/song.dart';

class LyricsResult {
  const LyricsResult({
    required this.text,
    required this.source,
    required this.isTimed,
  });

  final String text;
  final String source;
  final bool isTimed;
}

abstract interface class LyricsProvider {
  Future<LyricsResult?> lyricsFor(Song song);
}

class LocalLyricsProvider implements LyricsProvider {
  const LocalLyricsProvider({this.maxSidecarBytes = 1024 * 1024});

  final int maxSidecarBytes;

  @override
  Future<LyricsResult?> lyricsFor(Song song) async {
    final embedded = song.lyrics?.trim();
    if (embedded != null && embedded.isNotEmpty) {
      return LyricsResult(
        text: embedded,
        source: 'Embedded audio tags',
        isTimed: _hasTimestamps(embedded),
      );
    }

    final sidecar = File(p.setExtension(song.path, '.lrc'));
    try {
      if (!await sidecar.exists() || await sidecar.length() > maxSidecarBytes) {
        return null;
      }
      final text = (await sidecar.readAsString()).trim();
      if (text.isEmpty) return null;
      return LyricsResult(
        text: text,
        source: 'Local .lrc file',
        isTimed: _hasTimestamps(text),
      );
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static bool _hasTimestamps(String text) =>
      RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{2,3})?\]').hasMatch(text);
}

final lyricsProvider = Provider<LyricsProvider>(
  (ref) => const LocalLyricsProvider(),
);

final songLyricsProvider = FutureProvider.family<LyricsResult?, Song>((
  ref,
  song,
) {
  return ref.watch(lyricsProvider).lyricsFor(song);
});
