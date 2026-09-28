import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../library/domain/song.dart';
import '../domain/playlist.dart';
import '../domain/smart_playlist_rule.dart';

class PlaylistRepository {
  const PlaylistRepository(this.database);

  final Database database;

  Future<List<Playlist>> getAll() async {
    final rows = await database.rawQuery('''
      SELECT p.*, COUNT(pt.song_id) AS track_count,
        COALESCE(SUM(s.duration_ms), 0) AS duration_ms
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
      LEFT JOIN songs s ON s.id = pt.song_id
      GROUP BY p.id
      ORDER BY p.updated_at DESC, p.title COLLATE NOCASE ASC
    ''');
    final playlists = rows.map(Playlist.fromDatabaseMap).toList(growable: false);
    return Future.wait(playlists.map(_withSmartCounts));
  }

  Future<Playlist?> getById(String id) async {
    final rows = await database.rawQuery(
      '''
      SELECT p.*, COUNT(pt.song_id) AS track_count,
        COALESCE(SUM(s.duration_ms), 0) AS duration_ms
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
      LEFT JOIN songs s ON s.id = pt.song_id
      WHERE p.id = ?
      GROUP BY p.id LIMIT 1
    ''',
      [id],
    );
    return rows.isEmpty
        ? null
        : _withSmartCounts(Playlist.fromDatabaseMap(rows.single));
  }

  Future<List<Song>> getTracks(String playlistId) async {
    final playlistRows = await database.query(
      'playlists',
      where: 'id = ?',
      whereArgs: [playlistId],
      limit: 1,
    );
    if (playlistRows.isEmpty) return const [];
    final playlist = Playlist.fromDatabaseMap(playlistRows.single);
    if (playlist.isSmart) {
      return _getSmartTracks(playlist.smartRule ?? const SmartPlaylistRule());
    }
    final rows = await database.rawQuery(
      '''
      SELECT s.* FROM playlist_tracks pt
      JOIN songs s ON s.id = pt.song_id
      WHERE pt.playlist_id = ? ORDER BY pt.position ASC
    ''',
      [playlistId],
    );
    return rows.map(Song.fromDatabaseMap).toList(growable: false);
  }

  Future<Playlist> create(String title, {String? description}) async {
    final cleanedTitle = _validateTitle(title);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'playlist_${DateTime.now().microsecondsSinceEpoch}';
    await database.insert('playlists', {
      'id': id,
      'title': cleanedTitle,
      'description': _optionalText(description),
      'created_at': now,
      'updated_at': now,
    });
    return (await getById(id))!;
  }

  Future<Playlist> createSmart(
    String title,
    SmartPlaylistRule rule, {
    String? description,
  }) async {
    final cleanedTitle = _validateTitle(title);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'smart_${DateTime.now().microsecondsSinceEpoch}';
    await database.insert('playlists', {
      'id': id,
      'title': cleanedTitle,
      'description': _optionalText(description),
      'created_at': now,
      'updated_at': now,
      'is_smart': 1,
      'smart_rules_json': rule.encode(),
    });
    return (await getById(id))!;
  }

  Future<Playlist> updateSmartRule(
    String playlistId,
    SmartPlaylistRule rule,
  ) async {
    final changed = await database.update(
      'playlists',
      {
        'smart_rules_json': rule.encode(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND is_smart = 1',
      whereArgs: [playlistId],
    );
    if (changed == 0) throw StateError('Smart playlist no longer exists.');
    return (await getById(playlistId))!;
  }

  Future<void> rename(
    String playlistId,
    String title, {
    String? description,
  }) async {
    await database.update(
      'playlists',
      {
        'title': _validateTitle(title),
        'description': _optionalText(description),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> delete(String playlistId) =>
      database.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);

  Future<void> addTrack(String playlistId, String songId) =>
      database.transaction((txn) async {
        await _requirePlaylistAndSong(txn, playlistId, songId);
        final records = await _trackRecords(txn, playlistId);
        records.add(
          _PlaylistTrackRecord(songId, DateTime.now().millisecondsSinceEpoch),
        );
        await _replaceTracks(txn, playlistId, records);
      });

  Future<void> addTracks(String playlistId, Iterable<String> songIds) =>
      database.transaction((txn) async {
        final ids = songIds.toList(growable: false);
        if (ids.isEmpty) return;
        final playlist = await txn.query(
          'playlists',
          columns: ['id', 'is_smart'],
          where: 'id = ?',
          whereArgs: [playlistId],
          limit: 1,
        );
        if (playlist.isEmpty) throw StateError('Playlist no longer exists.');
        if ((playlist.single['is_smart'] as num?)?.toInt() == 1) {
          throw StateError('Rule-based smart playlists cannot be edited manually.');
        }
        final existingSongs = await txn.query('songs', columns: ['id']);
        final available = existingSongs
            .map((row) => row['id']! as String)
            .toSet();
        for (final id in ids) {
          if (!available.contains(id)) {
            throw StateError('Track no longer exists in the library.');
          }
        }
        final records = await _trackRecords(txn, playlistId);
        final now = DateTime.now().millisecondsSinceEpoch;
        records.addAll(ids.map((id) => _PlaylistTrackRecord(id, now)));
        await _replaceTracks(txn, playlistId, records);
      });

  Future<void> removeTrackAt(String playlistId, int position) =>
      database.transaction((txn) async {
        await _requireManualPlaylist(txn, playlistId);
        final records = await _trackRecords(txn, playlistId);
        if (position < 0 || position >= records.length) return;
        records.removeAt(position);
        await _replaceTracks(txn, playlistId, records);
      });

  /// `newIndex` follows ReorderableListView.onReorderItem's post-removal convention.
  Future<void> reorderTrack(String playlistId, int oldIndex, int newIndex) =>
      database.transaction((txn) async {
        await _requireManualPlaylist(txn, playlistId);
        final records = await _trackRecords(txn, playlistId);
        if (oldIndex < 0 || oldIndex >= records.length || records.isEmpty) {
          return;
        }
        final destination = newIndex.clamp(0, records.length - 1);
        if (oldIndex == destination) return;
        final track = records.removeAt(oldIndex);
        records.insert(destination, track);
        await _replaceTracks(txn, playlistId, records);
      });

  Future<Playlist> _withSmartCounts(Playlist playlist) async {
    if (!playlist.isSmart) return playlist;
    final songs = await _getSmartTracks(
      playlist.smartRule ?? const SmartPlaylistRule(),
    );
    final duration = songs.fold<int>(
      0,
      (total, song) => total + (song.durationMillis ?? 0),
    );
    return playlist.copyWith(
      trackCount: songs.length,
      durationMillis: duration,
    );
  }

  Future<List<Song>> _getSmartTracks(SmartPlaylistRule rule) async {
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (rule.favoritesOnly) conditions.add('s.is_favorite = 1');
    if (rule.losslessOnly) conditions.add('s.is_lossless = 1');
    if (rule.minimumRating case final rating?) {
      conditions.add('s.rating >= ?');
      arguments.add(rating.clamp(1, 5));
    }
    if (rule.minimumPlayCount case final count?) {
      conditions.add('s.play_count >= ?');
      arguments.add(count.clamp(1, 1000000));
    }
    if (rule.addedWithinDays case final days?) {
      conditions.add('s.added_at >= ?');
      arguments.add(
        DateTime.now()
            .subtract(Duration(days: days.clamp(1, 36500)))
            .millisecondsSinceEpoch,
      );
    }
    final genre = rule.genre?.trim();
    if (genre != null && genre.isNotEmpty) {
      conditions.add('LOWER(COALESCE(s.genre, \'\')) = LOWER(?)');
      arguments.add(genre);
    }
    final orderBy = switch (rule.sort) {
      SmartPlaylistSort.recentlyAdded => 's.added_at DESC, s.title COLLATE NOCASE ASC',
      SmartPlaylistSort.mostPlayed => 's.play_count DESC, s.last_played_at DESC',
      SmartPlaylistSort.highestRated => 's.rating DESC, s.play_count DESC',
      SmartPlaylistSort.title => 's.title COLLATE NOCASE ASC',
    };
    arguments.add(rule.limit.clamp(1, 1000));
    final rows = await database.rawQuery(
      'SELECT s.* FROM songs s'
      '${conditions.isEmpty ? '' : ' WHERE ${conditions.join(' AND ')}'}'
      ' ORDER BY $orderBy LIMIT ?',
      arguments,
    );
    return rows.map(Song.fromDatabaseMap).toList(growable: false);
  }

  Future<void> _requirePlaylistAndSong(
    DatabaseExecutor txn,
    String playlistId,
    String songId,
  ) async {
    final playlist = await txn.query(
      'playlists',
      columns: ['id', 'is_smart'],
      where: 'id = ?',
      whereArgs: [playlistId],
      limit: 1,
    );
    if (playlist.isEmpty) throw StateError('Playlist no longer exists.');
    if ((playlist.single['is_smart'] as num?)?.toInt() == 1) {
      throw StateError('Rule-based smart playlists cannot be edited manually.');
    }
    final song = await txn.query(
      'songs',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    if (song.isEmpty) {
      throw StateError('Track no longer exists in the library.');
    }
  }

  Future<void> _requireManualPlaylist(
    DatabaseExecutor txn,
    String playlistId,
  ) async {
    final rows = await txn.query(
      'playlists',
      columns: ['is_smart'],
      where: 'id = ?',
      whereArgs: [playlistId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Playlist no longer exists.');
    if ((rows.single['is_smart'] as num?)?.toInt() == 1) {
      throw StateError('Rule-based smart playlists cannot be edited manually.');
    }
  }

  Future<List<_PlaylistTrackRecord>> _trackRecords(
    DatabaseExecutor txn,
    String playlistId,
  ) async {
    final rows = await txn.query(
      'playlist_tracks',
      columns: ['song_id', 'added_at'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );
    return rows
        .map(
          (row) => _PlaylistTrackRecord(
            row['song_id']! as String,
            (row['added_at'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<void> _replaceTracks(
    DatabaseExecutor txn,
    String playlistId,
    List<_PlaylistTrackRecord> records,
  ) async {
    await txn.delete(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    final batch = txn.batch();
    for (var index = 0; index < records.length; index++) {
      batch.insert('playlist_tracks', {
        'playlist_id': playlistId,
        'song_id': records[index].songId,
        'position': index,
        'added_at': records[index].addedAt,
      });
    }
    await batch.commit(noResult: true);
    await txn.update(
      'playlists',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  static String _validateTitle(String title) {
    final value = title.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Cannot be empty.');
    }
    if (value.length > 100) {
      throw ArgumentError.value(
        title,
        'title',
        'Must be at most 100 characters.',
      );
    }
    return value;
  }

  static String? _optionalText(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

class _PlaylistTrackRecord {
  const _PlaylistTrackRecord(this.songId, this.addedAt);
  final String songId;
  final int addedAt;
}
