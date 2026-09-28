import 'dart:io';

import 'package:cadence_music/core/database/app_database.dart';
import 'package:cadence_music/features/library/data/artwork_cache.dart';
import 'package:cadence_music/features/library/data/local_library_indexer.dart';
import 'package:cadence_music/features/library/data/local_library_repository.dart';
import 'package:cadence_music/features/library/domain/audio_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('indexes local formats incrementally and reconciles removed files safely', () async {
    final temp = await Directory.systemTemp.createTemp('cadence-library-');
    addTearDown(() => temp.delete(recursive: true));
    final music = Directory(p.join(temp.path, 'music'))..createSync();
    final album = Directory(p.join(music.path, 'Album'))..createSync();
    final hidden = Directory(p.join(music.path, '.hidden'))..createSync();
    final first = File(p.join(album.path, '01-amber.MP3'))..writeAsBytesSync([1, 2, 3]);
    final second = File(p.join(music.path, 'blue.flac'))..writeAsBytesSync([4, 5, 6, 7]);
    File(p.join(hidden.path, 'ignored.mp3')).writeAsBytesSync([9]);
    File(p.join(music.path, 'cover.jpg')).writeAsBytesSync([8]);

    final database = await AppDatabase.open(inMemory: true);
    addTearDown(database.close);
    final repository = LocalLibraryRepository(database.connection);
    final root = await repository.putRoot(music.path, id: 'fixture-root');
    final reader = _FixtureMetadataReader();
    final indexer = LocalLibraryIndexer(
      repository: repository,
      metadataReader: reader,
      artworkCache: ArtworkCache(directoryPath: p.join(temp.path, 'artwork')),
    );

    final firstScan = await indexer.scanRoot(root);
    expect(firstScan.filesDiscovered, 2);
    expect(firstScan.tracksIndexed, 2);
    expect(firstScan.skipped, 0);
    expect(reader.readCount, 2);
    expect((await repository.getSongsForRoot(root.id)).map((song) => song.title), containsAll(['01-amber', 'blue']));

    final secondScan = await indexer.scanRoot(root);
    expect(secondScan.unchanged, 2);
    expect(secondScan.tracksIndexed, 0);
    expect(reader.readCount, 2);

    await first.delete();
    final thirdScan = await indexer.scanRoot(root);
    expect(thirdScan.filesDiscovered, 1);
    expect(thirdScan.unchanged, 1);
    expect((await repository.getSongsForRoot(root.id)).map((song) => song.title), ['blue']);
    expect(await second.exists(), isTrue);
  });

  test('explicit file import does not add a watched folder and skips invalid paths', () async {
    final temp = await Directory.systemTemp.createTemp('cadence-import-');
    addTearDown(() => temp.delete(recursive: true));
    final audio = File(p.join(temp.path, 'single.wav'))..writeAsBytesSync([1, 2, 3]);
    final database = await AppDatabase.open(inMemory: true);
    addTearDown(database.close);
    final repository = LocalLibraryRepository(database.connection);
    final indexer = LocalLibraryIndexer(
      repository: repository,
      metadataReader: _FixtureMetadataReader(),
      artworkCache: ArtworkCache(directoryPath: p.join(temp.path, 'artwork')),
    );

    final completed = await indexer.importFiles([
      audio.path,
      p.join(temp.path, 'missing.flac'),
      p.join(temp.path, 'note.txt'),
    ]);

    expect(completed, 1);
    expect((await repository.getSongs()).single.title, 'single');
    expect(await repository.getRoots(), isEmpty);
  });
}

class _FixtureMetadataReader implements AudioMetadataReader {
  int readCount = 0;

  @override
  Future<AudioMetadata> read(String path) async {
    readCount++;
    return AudioMetadata(
      title: p.basenameWithoutExtension(path),
      artist: 'Fixture artist',
      album: 'Fixture album',
      lyrics: 'One local lyric line',
      durationMillis: 123000,
    );
  }
}
