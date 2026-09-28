import 'dart:io';

import 'package:cadence_music/core/database/app_database.dart';
import 'package:cadence_music/features/library/data/local_library_repository.dart';
import 'package:cadence_music/features/library/domain/song.dart';
import 'package:cadence_music/features/playlists/data/playlist_repository.dart';
import 'package:cadence_music/features/playlists/domain/smart_playlist_rule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates the local-first schema and lyrics column', () async {
    final database = await AppDatabase.open(inMemory: true);
    addTearDown(database.close);

    final tables = await database.connection.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).whereType<String>().toSet();
    final songColumns = await database.connection.rawQuery(
      'PRAGMA table_info(songs)',
    );
    final columnNames = songColumns
        .map((row) => row['name'])
        .whereType<String>();

    expect(
      names,
      containsAll(<String>{
        'library_roots',
        'songs',
        'artists',
        'albums',
        'playlists',
        'playlist_tracks',
        'play_history',
        'downloads',
        'settings',
        'cached_metadata',
        'recent_searches',
      }),
    );
    expect(columnNames, contains('lyrics'));
  });

  test('upgrades a v2 songs table without losing existing rows', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'cadence-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'legacy.sqlite');
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE songs (id TEXT PRIMARY KEY, title TEXT NOT NULL)',
          );
          await db.insert('songs', {
            'id': 'existing-track',
            'title': 'Keep me',
          });
        },
      ),
    );
    await legacy.close();

    final migrated = await AppDatabase.open(databasePath: path);
    addTearDown(migrated.close);
    final row = (await migrated.connection.query('songs')).single;
    final columns = await migrated.connection.rawQuery(
      'PRAGMA table_info(songs)',
    );

    expect(row['id'], 'existing-track');
    expect(row['title'], 'Keep me');
    expect(columns.map((column) => column['name']), contains('lyrics'));
  });

  test(
    'library search, favorites, and play history use normalized metadata rows',
    () async {
      final database = await AppDatabase.open(inMemory: true);
      addTearDown(database.close);
      final repository = LocalLibraryRepository(database.connection);
      final first = _song(
        '/music/Amber.mp3',
        title: 'Amber Skies',
        artist: 'North Shore',
      );
      final second = _song(
        '/music/Blue.wav',
        title: 'Blue Hour',
        artist: 'North Shore',
      );
      await repository.upsertSongs([first, second]);

      await repository.setFavorite(first.id, true);
      await repository.markPlayed(second.id);

      final matching = await repository.getSongs(query: 'north', limit: 10);
      final favorites = await repository.getSongs(
        favoritesOnly: true,
        limit: 10,
      );
      final counts = await repository.getCounts();
      final recent = await repository.getRecentlyPlayed();

      expect(
        matching.map((song) => song.title),
        containsAll(['Amber Skies', 'Blue Hour']),
      );
      expect(favorites.map((song) => song.id), [first.id]);
      expect(counts, (tracks: 2, favorites: 1));
      expect(recent.map((song) => song.id), [second.id]);
    },
  );

  test(
    'playlist CRUD and reorder persist atomically without losing songs',
    () async {
      final database = await AppDatabase.open(inMemory: true);
      addTearDown(database.close);
      final library = LocalLibraryRepository(database.connection);
      final playlists = PlaylistRepository(database.connection);
      final songs = [
        _song('/music/one.mp3', title: 'One'),
        _song('/music/two.mp3', title: 'Two'),
        _song('/music/three.mp3', title: 'Three'),
      ];
      await library.upsertSongs(songs);
      final playlist = await playlists.create('Focus set');
      await playlists.addTracks(playlist.id, songs.map((song) => song.id));

      await playlists.reorderTrack(playlist.id, 0, 2);
      expect(
        (await playlists.getTracks(playlist.id)).map((song) => song.title),
        ['Two', 'Three', 'One'],
      );

      await playlists.removeTrackAt(playlist.id, 1);
      expect(
        (await playlists.getTracks(playlist.id)).map((song) => song.title),
        ['Two', 'One'],
      );
      await playlists.rename(playlist.id, 'Updated focus');
      expect((await playlists.getById(playlist.id))?.title, 'Updated focus');

      await playlists.delete(playlist.id);
      expect(await playlists.getAll(), isEmpty);
      expect(await library.getCounts(), (tracks: 3, favorites: 0));
    },
  );

  test('smart playlists match live library rules without manual edits', () async {
    final database = await AppDatabase.open(inMemory: true);
    addTearDown(database.close);
    final library = LocalLibraryRepository(database.connection);
    final playlists = PlaylistRepository(database.connection);
    final now = DateTime.now().millisecondsSinceEpoch;
    final songs = [
      Song(
        id: '/music/match.flac',
        path: '/music/match.flac',
        title: 'Match',
        genre: 'Jazz',
        modifiedAtMillis: now,
        fileSizeBytes: 500,
        addedAtMillis: now,
        durationMillis: 180000,
        isLossless: true,
        rating: 5,
        playCount: 8,
        isFavorite: true,
      ),
      Song(
        id: '/music/rating.flac',
        path: '/music/rating.flac',
        title: 'Low rated',
        genre: 'Jazz',
        modifiedAtMillis: now,
        fileSizeBytes: 500,
        addedAtMillis: now,
        durationMillis: 210000,
        isLossless: true,
        rating: 3,
        playCount: 10,
        isFavorite: true,
      ),
      Song(
        id: '/music/genre.flac',
        path: '/music/genre.flac',
        title: 'Different genre',
        genre: 'Rock',
        modifiedAtMillis: now,
        fileSizeBytes: 500,
        addedAtMillis: now,
        durationMillis: 240000,
        isLossless: true,
        rating: 5,
        playCount: 10,
      ),
    ];
    await library.upsertSongs(songs);
    final rule = SmartPlaylistRule(
      favoritesOnly: true,
      losslessOnly: true,
      minimumRating: 4,
      minimumPlayCount: 5,
      addedWithinDays: 30,
      genre: 'jazz',
      sort: SmartPlaylistSort.highestRated,
    );
    final playlist = await playlists.createSmart('Jazz picks', rule);

    expect(playlist.isSmart, isTrue);
    expect(playlist.trackCount, 1);
    expect(playlist.durationMillis, 180000);
    expect((await playlists.getTracks(playlist.id)).map((song) => song.title), ['Match']);
    expect(() => playlists.addTrack(playlist.id, songs.first.id), throwsStateError);
    expect(() => playlists.removeTrackAt(playlist.id, 0), throwsStateError);

    final changed = await playlists.updateSmartRule(
      playlist.id,
      const SmartPlaylistRule(losslessOnly: true, sort: SmartPlaylistSort.title),
    );
    expect(changed.trackCount, 3);
    expect((await playlists.getTracks(playlist.id)).map((song) => song.title), [
      'Different genre',
      'Low rated',
      'Match',
    ]);
  });
}

Song _song(String path, {required String title, String? artist}) => Song(
  id: path,
  path: path,
  title: title,
  artist: artist,
  lyrics: 'A local line',
  modifiedAtMillis: 100,
  fileSizeBytes: 10,
  addedAtMillis: 100,
);
