import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/audio_metadata.dart';
import '../domain/song.dart';
import 'artwork_cache.dart';
import 'local_library_repository.dart';

const supportedAudioExtensions = <String>{
  '.mp3',
  '.m4a',
  '.aac',
  '.flac',
  '.wav',
  '.ogg',
  '.opus',
};

class ScanProgress {
  const ScanProgress({
    required this.filesDiscovered,
    required this.tracksIndexed,
    required this.unchanged,
    required this.skipped,
  });

  final int filesDiscovered;
  final int tracksIndexed;
  final int unchanged;
  final int skipped;
}

class ScanSummary {
  const ScanSummary({
    required this.filesDiscovered,
    required this.tracksIndexed,
    required this.unchanged,
    required this.skipped,
    required this.couldNotReadDirectories,
  });

  final int filesDiscovered;
  final int tracksIndexed;
  final int unchanged;
  final int skipped;
  final int couldNotReadDirectories;
}

class LocalLibraryIndexer {
  const LocalLibraryIndexer({
    required this.repository,
    required this.metadataReader,
    required this.artworkCache,
  });

  final LocalLibraryRepository repository;
  final AudioMetadataReader metadataReader;
  final ArtworkCache artworkCache;

  Future<ScanSummary> scanRoot(
    LibraryRoot root, {
    void Function(ScanProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final rootPath = canonicalPath(root.path);
    final rootDirectory = Directory(rootPath);
    if (!await rootDirectory.exists()) {
      throw FileSystemException(
        'The selected music folder is unavailable.',
        rootPath,
      );
    }
    final previous = await repository.getSongsForRoot(root.id);
    final previousByPath = {
      for (final song in previous) _pathKey(song.path): song,
    };
    final seenAbsolutePaths = <String>{};
    final pendingSongs = <Song>[];
    final directories = <Directory>[rootDirectory];
    var discovered = 0;
    var indexed = 0;
    var unchanged = 0;
    var skipped = 0;
    var unreadableDirectories = 0;

    while (directories.isNotEmpty && !(isCancelled?.call() ?? false)) {
      final directory = directories.removeLast();
      try {
        await for (final entity in directory.list(followLinks: false)) {
          if (isCancelled?.call() ?? false) break;
          if (entity is Directory) {
            if (!_isHiddenDirectory(entity.path)) directories.add(entity);
            continue;
          }
          if (entity is! File || !_isAudioFile(entity.path)) continue;

          discovered++;
          final absolutePath = canonicalPath(entity.path);
          final key = _pathKey(absolutePath);
          seenAbsolutePaths.add(absolutePath);
          try {
            final stat = await entity.stat();
            final existing = previousByPath[key];
            final modifiedAt = stat.modified.millisecondsSinceEpoch;
            if (existing != null &&
                existing.modifiedAtMillis == modifiedAt &&
                existing.fileSizeBytes == stat.size) {
              unchanged++;
            } else {
              final metadata = await metadataReader.read(absolutePath);
              pendingSongs.add(
                await _toSong(
                  path: absolutePath,
                  rootId: root.id,
                  stat: stat,
                  metadata: metadata,
                  existing: existing,
                ),
              );
              indexed++;
            }
            if (pendingSongs.length >= 40) {
              await repository.upsertSongs(pendingSongs);
              pendingSongs.clear();
            }
          } catch (error, stackTrace) {
            skipped++;
            developer.log(
              'Skipping unreadable local audio file.',
              name: 'cadence.library.indexer',
              error: error,
              stackTrace: stackTrace,
            );
          }
          if (discovered % 20 == 0) {
            onProgress?.call(
              ScanProgress(
                filesDiscovered: discovered,
                tracksIndexed: indexed,
                unchanged: unchanged,
                skipped: skipped,
              ),
            );
          }
        }
      } on FileSystemException catch (error, stackTrace) {
        unreadableDirectories++;
        developer.log(
          'A music directory could not be read; keeping existing tracks for safety.',
          name: 'cadence.library.indexer',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (pendingSongs.isNotEmpty) await repository.upsertSongs(pendingSongs);
    final cancelled = isCancelled?.call() ?? false;
    if (unreadableDirectories == 0 && !cancelled) {
      // Never remove old entries if any directory was unreadable or the user
      // cancelled. Stored paths are actual absolute paths, not normalized IDs.
      await repository.deleteSongsNotInRoot(root.id, seenAbsolutePaths);
      await artworkCache.prune();
      await repository.updateRootScan(
        root.id,
        scannedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
    } else if (unreadableDirectories > 0 && !cancelled) {
      await repository.updateRootScan(
        root.id,
        scannedAtMillis: DateTime.now().millisecondsSinceEpoch,
        error:
            '$unreadableDirectories folder(s) could not be read; existing entries were kept.',
      );
    }

    final summary = ScanSummary(
      filesDiscovered: discovered,
      tracksIndexed: indexed,
      unchanged: unchanged,
      skipped: skipped,
      couldNotReadDirectories: unreadableDirectories,
    );
    onProgress?.call(
      ScanProgress(
        filesDiscovered: discovered,
        tracksIndexed: indexed,
        unchanged: unchanged,
        skipped: skipped,
      ),
    );
    return summary;
  }

  /// Imports explicitly dropped audio files without silently adding their
  /// containing folders to the user's watched library roots.
  Future<int> importFiles(
    Iterable<String> inputPaths, {
    void Function(int discovered, int completed, int skipped)? onProgress,
    bool Function()? isCancelled,
  }) async {
    var discovered = 0;
    var completed = 0;
    var skipped = 0;
    for (final input in inputPaths) {
      if (isCancelled?.call() ?? false) break;
      if (!_isAudioFile(input)) continue;
      discovered++;
      final path = canonicalPath(input);
      try {
        final file = File(path);
        if (!await file.exists()) {
          skipped++;
          continue;
        }
        final stat = await file.stat();
        final id = _pathKey(path);
        final existing = await repository.getSong(id);
        final modifiedAt = stat.modified.millisecondsSinceEpoch;
        if (existing != null &&
            existing.modifiedAtMillis == modifiedAt &&
            existing.fileSizeBytes == stat.size) {
          completed++;
        } else {
          final metadata = await metadataReader.read(path);
          final song = await _toSong(
            path: path,
            rootId: existing?.libraryRootId,
            stat: stat,
            metadata: metadata,
            existing: existing,
          );
          await repository.upsertSong(song);
          completed++;
        }
      } catch (error, stackTrace) {
        skipped++;
        developer.log(
          'Skipping unreadable dropped audio file.',
          name: 'cadence.library.indexer',
          error: error,
          stackTrace: stackTrace,
        );
      }
      onProgress?.call(discovered, completed, skipped);
    }
    await artworkCache.prune();
    return completed;
  }

  Future<Song> _toSong({
    required String path,
    required String? rootId,
    required FileStat stat,
    required AudioMetadata metadata,
    required Song? existing,
  }) async {
    final modifiedAt = stat.modified.millisecondsSinceEpoch;
    final key = _pathKey(path);
    final artworkPath = await artworkCache.store(
      songId: key,
      modifiedAtMillis: modifiedAt,
      bytes: metadata.artworkBytes,
      mimeType: metadata.artworkMimeType,
    );
    return Song(
      id: key,
      path: path,
      libraryRootId: rootId,
      title: _clean(metadata.title) ?? p.basenameWithoutExtension(path),
      artist: _clean(metadata.artist),
      album: _clean(metadata.album),
      albumArtist: _clean(metadata.albumArtist),
      genre: _clean(metadata.genre),
      lyrics: _clean(metadata.lyrics),
      year: metadata.year,
      trackNumber: metadata.trackNumber,
      discNumber: metadata.discNumber,
      durationMillis: metadata.durationMillis,
      modifiedAtMillis: modifiedAt,
      fileSizeBytes: metadata.fileSizeBytes ?? stat.size,
      codec: metadata.codec,
      containerFormat: metadata.containerFormat,
      sampleRate: metadata.sampleRate,
      bitsPerSample: metadata.bitsPerSample,
      channels: metadata.channels,
      isLossless: metadata.lossless ?? existing?.isLossless ?? false,
      bitrate: metadata.bitrate,
      bitrateMode: metadata.bitrateMode,
      bpm: metadata.bpm,
      replayGainTrackGain: metadata.replayGainTrackGain,
      replayGainTrackPeak: metadata.replayGainTrackPeak,
      replayGainAlbumGain: metadata.replayGainAlbumGain,
      replayGainAlbumPeak: metadata.replayGainAlbumPeak,
      artworkPath: artworkPath,
      addedAtMillis:
          existing?.addedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
      lastPlayedAtMillis: existing?.lastPlayedAtMillis,
      playCount: existing?.playCount ?? 0,
      skipCount: existing?.skipCount ?? 0,
      completionPercent: existing?.completionPercent,
      rating: existing?.rating ?? 0,
      isFavorite: existing?.isFavorite ?? false,
    );
  }

  static bool _isAudioFile(String path) =>
      supportedAudioExtensions.contains(p.extension(path).toLowerCase());

  static String canonicalPath(String path) => p.normalize(p.absolute(path));

  static String _pathKey(String path) {
    final normalized = canonicalPath(path);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static bool _isHiddenDirectory(String path) {
    final name = p.basename(path);
    return name.startsWith('.') ||
        name == 'System Volume Information' ||
        name == r'$RECYCLE.BIN';
  }

  static String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
