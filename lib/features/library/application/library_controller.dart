import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/repository_providers.dart';
import '../data/artwork_cache.dart';
import '../data/local_library_indexer.dart';
import '../data/metadata_reader_provider.dart';
import '../domain/song.dart';
import '../data/local_library_repository.dart';

final localLibraryIndexerProvider = Provider<LocalLibraryIndexer>((ref) {
  return LocalLibraryIndexer(
    repository: ref.watch(localLibraryRepositoryProvider),
    metadataReader: ref.watch(audioMetadataReaderProvider),
    artworkCache: const ArtworkCache(),
  );
});

final libraryControllerProvider =
    NotifierProvider<LibraryController, LibraryViewState>(
      LibraryController.new,
    );

class LibraryViewState {
  const LibraryViewState({
    this.songs = const [],
    this.roots = const [],
    this.trackCount = 0,
    this.favoriteCount = 0,
    this.isLoading = false,
    this.isScanning = false,
    this.filesDiscovered = 0,
    this.tracksIndexed = 0,
    this.unchanged = 0,
    this.skipped = 0,
    this.error,
  });

  final List<Song> songs;
  final List<LibraryRoot> roots;
  final int trackCount;
  final int favoriteCount;
  final bool isLoading;
  final bool isScanning;
  final int filesDiscovered;
  final int tracksIndexed;
  final int unchanged;
  final int skipped;
  final String? error;

  LibraryViewState copyWith({
    List<Song>? songs,
    List<LibraryRoot>? roots,
    int? trackCount,
    int? favoriteCount,
    bool? isLoading,
    bool? isScanning,
    int? filesDiscovered,
    int? tracksIndexed,
    int? unchanged,
    int? skipped,
    String? error,
    bool clearError = false,
  }) => LibraryViewState(
    songs: songs ?? this.songs,
    roots: roots ?? this.roots,
    trackCount: trackCount ?? this.trackCount,
    favoriteCount: favoriteCount ?? this.favoriteCount,
    isLoading: isLoading ?? this.isLoading,
    isScanning: isScanning ?? this.isScanning,
    filesDiscovered: filesDiscovered ?? this.filesDiscovered,
    tracksIndexed: tracksIndexed ?? this.tracksIndexed,
    unchanged: unchanged ?? this.unchanged,
    skipped: skipped ?? this.skipped,
    error: clearError ? null : error ?? this.error,
  );
}

class LibraryController extends Notifier<LibraryViewState> {
  bool _disposed = false;
  bool _scanLock = false;
  bool _cancelRequested = false;

  @override
  LibraryViewState build() {
    ref.onDispose(() => _disposed = true);
    scheduleMicrotask(() => refresh(clearError: true));
    return const LibraryViewState(isLoading: true);
  }

  Future<void> refresh({bool clearError = false}) async {
    if (_disposed) return;
    try {
      final repository = ref.read(localLibraryRepositoryProvider);
      final roots = await repository.getRoots();
      final songs = await repository.getSongs(limit: 5000);
      final counts = await repository.getCounts();
      if (_disposed) return;
      state = state.copyWith(
        roots: roots,
        songs: songs,
        trackCount: counts.tracks,
        favoriteCount: counts.favorites,
        isLoading: false,
        clearError: clearError,
      );
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Cadence could not load the local library. Try again.',
      );
    }
  }

  Future<void> addFolder(String path) async {
    if (_scanLock) return;
    _scanLock = true;
    _cancelRequested = false;
    state = state.copyWith(
      isScanning: true,
      filesDiscovered: 0,
      tracksIndexed: 0,
      unchanged: 0,
      skipped: 0,
      clearError: true,
    );
    try {
      final normalized = LocalLibraryIndexer.canonicalPath(path);
      final pathKey = Platform.isWindows
          ? normalized.toLowerCase()
          : normalized;
      final roots = await ref.read(localLibraryRepositoryProvider).getRoots();
      for (final existing in roots) {
        final existingPath = LocalLibraryIndexer.canonicalPath(existing.path);
        final existingKey = Platform.isWindows
            ? existingPath.toLowerCase()
            : existingPath;
        if (existingKey == pathKey) {
          await _scan(existing);
          return;
        }
        if (p.isWithin(existingKey, pathKey) ||
            p.isWithin(pathKey, existingKey)) {
          state = state.copyWith(
            error: 'This folder overlaps an indexed folder. Remove the existing folder first.',
          );
          return;
        }
      }
      final root = await ref
          .read(localLibraryRepositoryProvider)
          .putRoot(normalized, id: pathKey);
      await _scan(root);
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          error: 'Cadence could not read that folder. Check its permissions and try again.',
        );
      }
    } finally {
      _scanLock = false;
      _cancelRequested = false;
      if (!_disposed) {
        state = state.copyWith(isScanning: false);
        await refresh();
      }
    }
  }

  Future<void> rescanRoot(LibraryRoot root) => addFolder(root.path);

  Future<void> importFiles(Iterable<String> paths) async {
    if (_scanLock) return;
    final inputPaths = paths.toList(growable: false);
    _scanLock = true;
    _cancelRequested = false;
    state = state.copyWith(isScanning: true, clearError: true);
    try {
      final indexed = await ref
          .read(localLibraryIndexerProvider)
          .importFiles(
            inputPaths,
            isCancelled: () => _cancelRequested,
            onProgress: (discovered, completed, skipped) {
              if (_disposed) return;
              state = state.copyWith(
                filesDiscovered: discovered,
                tracksIndexed: completed,
                skipped: skipped,
              );
            },
          );
      if (indexed == 0 &&
          inputPaths.isNotEmpty &&
          !_cancelRequested &&
          !_disposed) {
        state = state.copyWith(
          error: 'No supported audio files could be read.',
        );
      }
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(error: 'Some audio files could not be added.');
      }
    } finally {
      _scanLock = false;
      _cancelRequested = false;
      if (!_disposed) {
        state = state.copyWith(isScanning: false);
        await refresh();
      }
    }
  }

  Future<void> removeFolder(LibraryRoot root) async {
    await ref.read(localLibraryRepositoryProvider).removeRoot(root.id);
    await refresh();
  }

  Future<void> removeSong(Song song) async {
    await ref.read(localLibraryRepositoryProvider).removeSong(song.id);
    await refresh();
  }

  Future<void> setFavorite(Song song, bool favorite) async {
    await ref
        .read(localLibraryRepositoryProvider)
        .setFavorite(song.id, favorite);
    await refresh();
  }

  void cancelScan() => _cancelRequested = true;

  Future<void> _scan(LibraryRoot root) async {
    await ref
        .read(localLibraryIndexerProvider)
        .scanRoot(
          root,
          isCancelled: () => _cancelRequested,
          onProgress: (progress) {
            if (_disposed) return;
            state = state.copyWith(
              filesDiscovered: progress.filesDiscovered,
              tracksIndexed: progress.tracksIndexed,
              unchanged: progress.unchanged,
              skipped: progress.skipped,
            );
          },
        );
  }
}
