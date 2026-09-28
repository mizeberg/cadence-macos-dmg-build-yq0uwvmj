import 'dart:io';

import 'package:cadence_music/features/library/domain/song.dart';
import 'package:cadence_music/features/playback/data/lyrics_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('prefers embedded lyrics and recognizes timed lyrics', () async {
    final provider = const LocalLyricsProvider();
    final result = await provider.lyricsFor(_song('/music/track.mp3', lyrics: '[00:12.00]First line'));

    expect(result?.source, 'Embedded audio tags');
    expect(result?.isTimed, isTrue);
    expect(result?.text, '[00:12.00]First line');
  });

  test('loads only a bounded adjacent LRC sidecar when tags have no lyrics', () async {
    final temp = await Directory.systemTemp.createTemp('cadence-lyrics-');
    addTearDown(() => temp.delete(recursive: true));
    final audio = p.join(temp.path, 'track.mp3');
    final lrc = File(p.setExtension(audio, '.lrc'));
    await lrc.writeAsString('[00:01.20]A line\n[00:02.30]Another line');
    final provider = const LocalLyricsProvider(maxSidecarBytes: 64);

    final result = await provider.lyricsFor(_song(audio));
    expect(result?.source, 'Local .lrc file');
    expect(result?.isTimed, isTrue);

    await lrc.writeAsString('x' * 100);
    expect(await provider.lyricsFor(_song(audio)), isNull);
  });
}

Song _song(String path, {String? lyrics}) => Song(
  id: path,
  path: path,
  title: 'Local song',
  lyrics: lyrics,
  modifiedAtMillis: 1,
  fileSizeBytes: 1,
  addedAtMillis: 1,
);
