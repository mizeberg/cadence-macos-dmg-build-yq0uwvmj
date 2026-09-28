import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Owns the local metadata database. All SQLite work is asynchronous and
/// remains off the widget build path.
class AppDatabase {
  AppDatabase._(this.connection);

  final Database connection;

  static const schemaVersion = 4;

  static Future<AppDatabase> open({
    bool inMemory = false,
    String? databasePath,
  }) async {
    sqfliteFfiInit();
    final String path;
    if (databasePath != null) {
      path = databasePath;
    } else if (inMemory) {
      path = inMemoryDatabasePath;
    } else {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}${Platform.pathSeparator}Cadence',
      );
      await directory.create(recursive: true);
      path = '${directory.path}${Platform.pathSeparator}cadence.sqlite';
    }

    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
        },
        onCreate: (db, _) => _createV4Schema(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _upgradeToV2(db);
          if (oldVersion < 3) await _upgradeToV3(db);
          if (oldVersion < 4) await _upgradeToV4(db);
        },
      ),
    );
    return AppDatabase._(database);
  }

  static Future<void> _createV4Schema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE library_roots (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL UNIQUE,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        last_scan_at INTEGER,
        scan_error TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE songs (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL UNIQUE,
        library_root_id TEXT REFERENCES library_roots(id) ON DELETE SET NULL,
        title TEXT NOT NULL,
        artist TEXT,
        album TEXT,
        album_artist TEXT,
        genre TEXT,
        lyrics TEXT,
        year INTEGER,
        track_number INTEGER,
        disc_number INTEGER,
        duration_ms INTEGER,
        modified_at INTEGER NOT NULL,
        file_size INTEGER NOT NULL DEFAULT 0,
        codec TEXT,
        container_format TEXT,
        sample_rate INTEGER,
        bits_per_sample INTEGER,
        channels INTEGER,
        is_lossless INTEGER NOT NULL DEFAULT 0,
        bitrate INTEGER,
        bitrate_mode TEXT,
        bpm REAL,
        replaygain_track_gain REAL,
        replaygain_track_peak REAL,
        replaygain_album_gain REAL,
        replaygain_album_peak REAL,
        artwork_path TEXT,
        added_at INTEGER NOT NULL,
        last_played_at INTEGER,
        play_count INTEGER NOT NULL DEFAULT 0,
        skip_count INTEGER NOT NULL DEFAULT 0,
        completion_percent REAL,
        rating INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createSongIndexes(db);
    await db.execute('''
      CREATE TABLE artists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        artwork_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE albums (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL COLLATE NOCASE,
        artist_id TEXT REFERENCES artists(id) ON DELETE SET NULL,
        year INTEGER,
        artwork_path TEXT,
        UNIQUE(title, artist_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        artwork_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_smart INTEGER NOT NULL DEFAULT 0,
        smart_rules_json TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE playlist_tracks (
        playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
        song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, position)
      )
    ''');
    await db.execute(
      'CREATE INDEX playlist_tracks_song_idx ON playlist_tracks(song_id)',
    );
    await db.execute('''
      CREATE TABLE play_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
        played_at INTEGER NOT NULL,
        played_ms INTEGER NOT NULL DEFAULT 0,
        completion_percent REAL NOT NULL DEFAULT 0,
        skipped INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX play_history_played_idx ON play_history(played_at DESC)',
    );
    await db.execute('''
      CREATE TABLE downloads (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        source_item_id TEXT NOT NULL,
        file_path TEXT,
        state TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    await _createSettingsAndCache(db);
    await _createRecentSearches(db);
  }

  static Future<void> _upgradeToV2(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE library_roots (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL UNIQUE,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        last_scan_at INTEGER,
        scan_error TEXT
      )
    ''');
    await db.execute('''
      ALTER TABLE songs ADD COLUMN library_root_id TEXT
        REFERENCES library_roots(id) ON DELETE SET NULL
    ''');
    await db.execute(
      'ALTER TABLE songs ADD COLUMN file_size INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE songs ADD COLUMN codec TEXT');
    await db.execute('ALTER TABLE songs ADD COLUMN sample_rate INTEGER');
    await db.execute('ALTER TABLE songs ADD COLUMN bitrate INTEGER');
    await db.execute('ALTER TABLE songs ADD COLUMN last_played_at INTEGER');
    await _createSongIndexes(db);
    await _createRecentSearches(db);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS playlist_tracks_song_idx ON playlist_tracks(song_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS play_history_played_idx ON play_history(played_at DESC)',
    );
  }

  static Future<void> _upgradeToV3(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE songs ADD COLUMN lyrics TEXT');
  }

  static Future<void> _upgradeToV4(DatabaseExecutor db) async {
    const songColumns = <String>[
      'container_format TEXT',
      'bits_per_sample INTEGER',
      'channels INTEGER',
      'is_lossless INTEGER NOT NULL DEFAULT 0',
      'bitrate_mode TEXT',
      'bpm REAL',
      'replaygain_track_gain REAL',
      'replaygain_track_peak REAL',
      'replaygain_album_gain REAL',
      'replaygain_album_peak REAL',
      'play_count INTEGER NOT NULL DEFAULT 0',
      'skip_count INTEGER NOT NULL DEFAULT 0',
      'completion_percent REAL',
      'rating INTEGER NOT NULL DEFAULT 0',
    ];
    for (final column in songColumns) {
      await db.execute('ALTER TABLE songs ADD COLUMN $column');
    }
    if (await _tableExists(db, 'playlists')) {
      await db.execute(
        'ALTER TABLE playlists ADD COLUMN is_smart INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE playlists ADD COLUMN smart_rules_json TEXT',
      );
    }
    if (await _tableExists(db, 'play_history')) {
      await db.execute(
        'ALTER TABLE play_history ADD COLUMN completion_percent REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE play_history ADD COLUMN skipped INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  static Future<bool> _tableExists(
    DatabaseExecutor db,
    String tableName,
  ) async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', tableName],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<void> _createSongIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS songs_title_idx ON songs(title COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS songs_artist_idx ON songs(artist COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS songs_album_idx ON songs(album COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS songs_genre_idx ON songs(genre COLLATE NOCASE)',
    );
  }

  static Future<void> _createSettingsAndCache(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cached_metadata (
        cache_key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL,
        expires_at INTEGER
      )
    ''');
  }

  static Future<void> _createRecentSearches(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE recent_searches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL UNIQUE COLLATE NOCASE,
        used_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX recent_searches_used_idx ON recent_searches(used_at DESC)',
    );
  }

  Future<void> close() => connection.close();
}
