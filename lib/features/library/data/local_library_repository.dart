import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/song.dart';

class LibraryRoot {
  const LibraryRoot({
    required this.id,
    required this.path,
    required this.enabled,
    required this.createdAtMillis,
    this.lastScanAtMillis,
    this.scanError,
  });

  final String id;
  final String path;
  final bool enabled;
  final int createdAtMillis;
  final int? lastScanAtMillis;
  final String? scanError;

  factory LibraryRoot.fromMap(Map<String, Object?> row) => LibraryRoot(
    id: row['id']! as String,
    path: row['path']! as String,
    enabled: row['enabled'] != 0,
    createdAtMillis: _asInt(row['created_at']) ?? 0,
    lastScanAtMillis: _asInt(row['last_scan_at']),
    scanError: row['scan_error'] as String?,
  );

  static int? _asInt(Object? value) => switch (value) {
    int v => v,
    num v => v.toInt(),
    _ => null,
  };
}

enum LibrarySort { title, artist, album, dateAdded, duration, recentlyPlayed }

class LocalLibraryRepository {
  const LocalLibraryRepository(this.database);

  final Database database;

  Future<List<Song>> getSongs({
    String query = '',
    LibrarySort sort = LibrarySort.title,
    bool favoritesOnly = false,
    int limit = 5000,
  }) async {
    final normalizedQuery = query.trim();
    final where = <String>[];
    final arguments = <Object?>[];
    if (normalizedQuery.isNotEmpty) {
      where.add('''
        (instr(lower(title), lower(?)) > 0 OR
         instr(lower(COALESCE(artist, '')), lower(?)) > 0 OR
         instr(lower(COALESCE(album_artist, '')), lower(?)) > 0 OR
         instr(lower(COALESCE(album, '')), lower(?)) > 0 OR
         instr(lower(COALESCE(genre, '')), lower(?)) > 0)
      ''');
      arguments.addAll(List<Object?>.filled(5, normalizedQuery));
    }
    if (favoritesOnly) {
      where.add('is_favorite = 1');
    }
    final orderBy = switch (sort) {
      LibrarySort.title =>
        'title COLLATE NOCASE ASC, artist COLLATE NOCASE ASC',
      LibrarySort.artist =>
        'artist COLLATE NOCASE ASC, title COLLATE NOCASE ASC',
      LibrarySort.album =>
        'album COLLATE NOCASE ASC, track_number ASC, title COLLATE NOCASE ASC',
      LibrarySort.dateAdded => 'added_at DESC',
      LibrarySort.duration => 'duration_ms DESC',
      LibrarySort.recentlyPlayed => 'last_played_at DESC, added_at DESC',
    };
    final rows = await database.query(
      'songs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: orderBy,
      limit: limit,
    );
    return rows.map(Song.fromDatabaseMap).toList(growable: false);
  }

  Future<Song?> getSong(String id) async {
    final rows = await database.query(
      'songs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Song.fromDatabaseMap(rows.first);
  }

  Future<List<Song>> getSongsForRoot(String rootId) async {
    final rows = await database.query(
      'songs',
      where: 'library_root_id = ?',
      whereArgs: [rootId],
    );
    return rows.map(Song.fromDatabaseMap).toList(growable: false);
  }

  Future<({int tracks, int favorites})> getCounts() async {
    final row = (await database.rawQuery('''
      SELECT COUNT(*) AS tracks,
        COALESCE(SUM(CASE WHEN is_favorite = 1 THEN 1 ELSE 0 END), 0) AS favorites
      FROM songs
    ''')).single;
    return (
      tracks: (row['tracks'] as num).toInt(),
      favorites: (row['favorites'] as num).toInt(),
    );
  }

  Future<List<Song>> getRecentlyPlayed({int limit = 8}) async {
    final rows = await database.query(
      'songs',
      where: 'last_played_at IS NOT NULL',
      orderBy: 'last_played_at DESC',
      limit: limit,
    );
    return rows.map(Song.fromDatabaseMap).toList(growable: false);
  }

  Future<List<LibraryRoot>> getRoots({bool enabledOnly = false}) async {
    final rows = await database.query(
      'library_roots',
      where: enabledOnly ? 'enabled = 1' : null,
      orderBy: 'path COLLATE NOCASE ASC',
    );
    return rows.map(LibraryRoot.fromMap).toList(growable: false);
  }

  Future<LibraryRoot> putRoot(
    String path, {
    String? id,
    int? createdAtMillis,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rootId = id ?? path;
    await database.rawInsert(
      '''INSERT INTO library_roots (id, path, enabled, created_at)
         VALUES (?, ?, 1, ?)
         ON CONFLICT(path) DO UPDATE SET enabled = 1''',
      [rootId, path, createdAtMillis ?? now],
    );
    final rows = await database.query(
      'library_roots',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    return LibraryRoot.fromMap(rows.single);
  }

  Future<void> updateRootScan(
    String rootId, {
    required int scannedAtMillis,
    String? error,
  }) => database.update(
    'library_roots',
    {'last_scan_at': scannedAtMillis, 'scan_error': error},
    where: 'id = ?',
    whereArgs: [rootId],
  );

  Future<void> removeRoot(String rootId) => database.transaction((txn) async {
    await txn.delete(
      'songs',
      where: 'library_root_id = ?',
      whereArgs: [rootId],
    );
    await txn.delete('library_roots', where: 'id = ?', whereArgs: [rootId]);
  });

  Future<void> upsertSong(Song song) => _upsertSong(database, song);

  Future<void> upsertSongs(Iterable<Song> songs) async {
    final materialized = songs.toList(growable: false);
    if (materialized.isEmpty) return;
    await database.transaction((txn) async {
      for (final song in materialized) {
        await _upsertSong(txn, song);
      }
    });
  }

  Future<void> _upsertSong(DatabaseExecutor db, Song song) async {
    final row = song.toDatabaseMap();
    final columns = row.keys.toList(growable: false);
    final columnList = columns.join(', ');
    final placeholders = List.filled(columns.length, '?').join(', ');
    final updates = columns
        .skip(1)
        .map((column) => '$column = excluded.$column')
        .join(', ');
    await db.rawInsert(
      '''INSERT INTO songs ($columnList) VALUES ($placeholders)
         ON CONFLICT(id) DO UPDATE SET $updates''',
      row.values.toList(growable: false),
    );
  }

  Future<void> deleteSongsNotInRoot(
    String rootId,
    Set<String> seenPaths,
  ) async {
    await database.transaction((txn) async {
      final rows = await txn.query(
        'songs',
        columns: ['id', 'path'],
        where: 'library_root_id = ?',
        whereArgs: [rootId],
      );
      final stale = rows
          .where((row) => !seenPaths.contains(row['path']))
          .map((row) => row['id']! as String)
          .toList(growable: false);
      for (var offset = 0; offset < stale.length; offset += 400) {
        final chunk = stale.skip(offset).take(400).toList(growable: false);
        if (chunk.isEmpty) continue;
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.delete(
          'songs',
          where: 'id IN ($placeholders)',
          whereArgs: chunk,
        );
      }
    });
  }

  Future<void> removeSong(String id) =>
      database.delete('songs', where: 'id = ?', whereArgs: [id]);

  Future<void> setFavorite(String id, bool value) => database.update(
    'songs',
    {'is_favorite': value ? 1 : 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> setRating(String id, int rating) => database.update(
    'songs',
    {'rating': rating.clamp(0, 5)},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<int> markPlayed(String id, {int playedMillis = 0}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.transaction((txn) async {
      await txn.update(
        'songs',
        {'last_played_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.rawUpdate(
        'UPDATE songs SET play_count = play_count + 1 WHERE id = ?',
        [id],
      );
      return txn.insert('play_history', {
        'song_id': id,
        'played_at': now,
        'played_ms': playedMillis,
      });
    });
  }

  Future<void> finishPlaybackSession({
    required int historyId,
    required String songId,
    required int playedMillis,
    required int durationMillis,
    required bool skipped,
  }) async {
    final completion = durationMillis <= 0
        ? 0.0
        : (playedMillis / durationMillis * 100).clamp(0, 100).toDouble();
    await database.transaction((txn) async {
      await txn.update(
        'play_history',
        {
          'played_ms': playedMillis,
          'completion_percent': completion,
          'skipped': skipped ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [historyId],
      );
      await txn.rawUpdate(
        'UPDATE songs SET completion_percent = ?, skip_count = skip_count + ? WHERE id = ?',
        [completion, skipped ? 1 : 0, songId],
      );
    });
  }

  Future<void> addRecentSearch(String query, {int maxItems = 8}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.rawInsert(
      '''INSERT INTO recent_searches (query, used_at) VALUES (?, ?)
         ON CONFLICT(query) DO UPDATE SET used_at = excluded.used_at''',
      [normalized, now],
    );
    await database.rawDelete(
      '''DELETE FROM recent_searches WHERE id NOT IN (
         SELECT id FROM recent_searches ORDER BY used_at DESC LIMIT ?
      )''',
      [maxItems],
    );
  }

  Future<List<String>> getRecentSearches({int limit = 8}) async {
    final rows = await database.query(
      'recent_searches',
      columns: ['query'],
      orderBy: 'used_at DESC',
      limit: limit,
    );
    return rows.map((row) => row['query']! as String).toList(growable: false);
  }

  Future<void> clearRecentSearches() => database.delete('recent_searches');
}
