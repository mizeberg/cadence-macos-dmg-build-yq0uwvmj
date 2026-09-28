import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/repository_providers.dart';
import '../../playback/application/playback_controller.dart';
import '../../playlists/application/playlist_providers.dart';
import '../../library/application/library_controller.dart';
import '../../library/application/library_search_providers.dart';
import '../../library/data/local_library_indexer.dart';
import '../../library/data/local_library_repository.dart';
import '../../library/domain/song.dart';
import '../../shell/application/shell_state.dart';
import 'song_list_tile.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _dragging = false;

  Future<void> _chooseFolder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose a music folder',
      );
      if (path != null && mounted) {
        await ref.read(libraryControllerProvider.notifier).addFolder(path);
      }
    } catch (error) {
      _showMessage('The folder picker could not be opened.');
    }
  }

  Future<void> _chooseFiles() async {
    try {
      final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedAudioExtensions
            .map((extension) => extension.substring(1))
            .toList(growable: false),
      );
      if (files == null) return;
      final paths = files.files
          .map((file) => file.path)
          .whereType<String>()
          .toList(growable: false);
      if (paths.isNotEmpty && mounted) {
        await ref.read(libraryControllerProvider.notifier).importFiles(paths);
      }
    } catch (error) {
      _showMessage('The file picker could not be opened.');
    }
  }

  Future<void> _handleDrop(DropDoneDetails detail) async {
    final folders = <String>[];
    final audioFiles = <String>[];
    for (final dropped in detail.files) {
      final path = dropped.path;
      if (await Directory(path).exists()) {
        folders.add(path);
      } else if (supportedAudioExtensions.contains(
        p.extension(path).toLowerCase(),
      )) {
        audioFiles.add(path);
      }
    }
    if (!mounted) return;
    for (final folder in folders) {
      await ref.read(libraryControllerProvider.notifier).addFolder(folder);
    }
    if (audioFiles.isNotEmpty && mounted) {
      await ref
          .read(libraryControllerProvider.notifier)
          .importFiles(audioFiles);
    }
    if (folders.isEmpty && audioFiles.isEmpty) {
      _showMessage('Drop a supported audio file or a music folder.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeFolder(LibraryRoot root) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove folder from Cadence?'),
        content: Text(
          '“${p.basename(root.path)}” and its tracks will be removed from the library index. The audio files on disk will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep folder'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove from library'),
          ),
        ],
      ),
    );
    if (remove == true && mounted) {
      await ref.read(libraryControllerProvider.notifier).removeFolder(root);
    }
  }

  Future<void> _handleTrackAction(_TrackAction action, Song song) async {
    switch (action) {
      case _TrackAction.playNext:
        ref.read(playbackControllerProvider.notifier).playNext(song);
        _showMessage('Added to play next.');
      case _TrackAction.addToQueue:
        ref.read(playbackControllerProvider.notifier).addToQueue(song);
        _showMessage('Added to the queue.');
      case _TrackAction.favorite:
        await ref
            .read(libraryControllerProvider.notifier)
            .setFavorite(song, !song.isFavorite);
        ref.invalidate(librarySearchResultsProvider);
      case _TrackAction.addToPlaylist:
        await _addToPlaylist(song);
      case _TrackAction.removeFromLibrary:
        final remove = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove track from library?'),
            content: Text(
              '“${song.title}” will be unindexed. Its audio file will remain untouched.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (remove == true && mounted) {
          await ref.read(libraryControllerProvider.notifier).removeSong(song);
          ref.invalidate(librarySearchResultsProvider);
        }
    }
  }

  Future<void> _addToPlaylist(Song song) async {
    final playlists = await ref.read(playlistRepositoryProvider).getAll();
    if (!mounted) return;
    const createNew = '__create_new__';
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to playlist'),
        content: SizedBox(
          width: 360,
          child: playlists.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Create a playlist to organize this track.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(playlists[index].title),
                    onTap: () => Navigator.pop(context, playlists[index].id),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, createNew),
            child: const Text('New playlist'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final repository = ref.read(playlistRepositoryProvider);
    var playlistId = choice;
    if (choice == createNew) {
      final controller = TextEditingController();
      final title = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Playlist name'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (title == null || title.trim().isEmpty || !mounted) return;
      try {
        playlistId = (await repository.create(title)).id;
      } on ArgumentError {
        _showMessage('Enter a playlist name up to 100 characters.');
        return;
      }
    }
    try {
      await repository.addTrack(playlistId, song.id);
      ref.invalidate(playlistsProvider);
      _showMessage('Added to playlist.');
    } catch (error) {
      _showMessage('The track could not be added to that playlist.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final library = ref.watch(libraryControllerProvider);
    final query = ref.watch(searchQueryProvider).trim();
    final sort = ref.watch(librarySortProvider);
    final favoritesOnly = ref.watch(favoritesOnlyProvider);
    final results = ref.watch(
      librarySearchResultsProvider(
        LibraryQuery(query: query, sort: sort, favoritesOnly: favoritesOnly),
      ),
    );
    ref.listen(libraryControllerProvider.select((value) => value.error), (
      previous,
      next,
    ) {
      if (next != null && next != previous) _showMessage(next);
    });
    final songs = results.valueOrNull ?? const <Song>[];
    final playback = ref.watch(playbackControllerProvider);

    return DropTarget(
      onDragDone: _handleDrop,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 25, 30, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your library',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -.5,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${library.trackCount} indexed tracks · stored on this device',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh library',
                          onPressed: library.isScanning
                              ? null
                              : () => ref
                                    .read(libraryControllerProvider.notifier)
                                    .refresh(clearError: true),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: library.isScanning ? null : _chooseFiles,
                          icon: const Icon(Icons.audio_file_outlined, size: 18),
                          label: const Text('Add files'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: library.isScanning ? null : _chooseFolder,
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            size: 18,
                          ),
                          label: const Text('Add folder'),
                        ),
                      ],
                    ),
                    if (library.roots.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final root in library.roots)
                            InputChip(
                              avatar: const Icon(
                                Icons.folder_open_outlined,
                                size: 16,
                              ),
                              label: Text(
                                p.basename(root.path).isEmpty
                                    ? root.path
                                    : p.basename(root.path),
                              ),
                              tooltip: root.path,
                              onPressed: library.isScanning
                                  ? null
                                  : () => ref
                                        .read(
                                          libraryControllerProvider.notifier,
                                        )
                                        .rescanRoot(root),
                              onDeleted: library.isScanning
                                  ? null
                                  : () => _removeFolder(root),
                            ),
                        ],
                      ),
                    ],
                    if (library.isScanning) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: null,
                                  minHeight: 3,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Scanning ${library.filesDiscovered} files · ${library.tracksIndexed} added · ${library.skipped} unreadable',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(libraryControllerProvider.notifier)
                                .cancelScan(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            query.isEmpty ? 'Tracks' : 'Results for “$query”',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        FilterChip(
                          avatar: Icon(
                            favoritesOnly
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                          ),
                          label: const Text('Favorites'),
                          selected: favoritesOnly,
                          onSelected: (value) {
                            ref.read(favoritesOnlyProvider.notifier).state =
                                value;
                          },
                        ),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<LibrarySort>(
                            value: sort,
                            borderRadius: BorderRadius.circular(14),
                            items: const [
                              DropdownMenuItem(
                                value: LibrarySort.title,
                                child: Text('Title'),
                              ),
                              DropdownMenuItem(
                                value: LibrarySort.artist,
                                child: Text('Artist'),
                              ),
                              DropdownMenuItem(
                                value: LibrarySort.album,
                                child: Text('Album'),
                              ),
                              DropdownMenuItem(
                                value: LibrarySort.dateAdded,
                                child: Text('Recently added'),
                              ),
                              DropdownMenuItem(
                                value: LibrarySort.recentlyPlayed,
                                child: Text('Recently played'),
                              ),
                              DropdownMenuItem(
                                value: LibrarySort.duration,
                                child: Text('Duration'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                ref.read(librarySortProvider.notifier).state =
                                    value;
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: songs.isEmpty
                              ? null
                              : () => ref
                                    .read(playbackControllerProvider.notifier)
                                    .playQueue(songs),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    if (songs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                'TITLE',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      letterSpacing: .6,
                                    ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'ALBUM',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      letterSpacing: .6,
                                    ),
                              ),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(
                                'TIME',
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      letterSpacing: .6,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 78),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _LibraryEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Library unavailable',
                    message: 'Cadence could not query the local index.',
                    actionLabel: 'Try again',
                    onAction: () =>
                        ref.invalidate(librarySearchResultsProvider),
                  ),
                  data: (data) => data.isEmpty
                      ? _LibraryEmptyState(
                          icon: query.isNotEmpty || favoritesOnly
                              ? Icons.search_off_rounded
                              : Icons.library_music_outlined,
                          title: query.isNotEmpty || favoritesOnly
                              ? 'No matching tracks'
                              : 'Add your music folder',
                          message: query.isNotEmpty || favoritesOnly
                              ? 'Try a different search or turn off the favorites filter.'
                              : 'Cadence scans supported local audio tags and never moves or deletes the audio files.',
                          actionLabel: query.isNotEmpty || favoritesOnly
                              ? 'Clear filters'
                              : 'Choose folder',
                          onAction: query.isNotEmpty || favoritesOnly
                              ? () {
                                  ref
                                      .read(searchQueryProvider.notifier)
                                      .clear();
                                  ref
                                          .read(favoritesOnlyProvider.notifier)
                                          .state =
                                      false;
                                }
                              : _chooseFolder,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                          itemCount: data.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 2),
                          itemBuilder: (context, index) {
                            final song = data[index];
                            final current = playback.currentSong?.id == song.id;
                            return SongListTile(
                              song: song,
                              selected: current,
                              indexLabel: current && playback.isPlaying
                                  ? '▶'
                                  : '${index + 1}',
                              onTap: () => ref
                                  .read(playbackControllerProvider.notifier)
                                  .playQueue(data, startIndex: index),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: song.isFavorite
                                        ? 'Remove from favorites'
                                        : 'Add to favorites',
                                    onPressed: () async {
                                      await ref
                                          .read(
                                            libraryControllerProvider.notifier,
                                          )
                                          .setFavorite(song, !song.isFavorite);
                                      ref.invalidate(
                                        librarySearchResultsProvider,
                                      );
                                    },
                                    icon: Icon(
                                      song.isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 18,
                                      color: song.isFavorite
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  PopupMenuButton<_TrackAction>(
                                    tooltip: 'Track actions',
                                    onSelected: (action) =>
                                        _handleTrackAction(action, song),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: _TrackAction.playNext,
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.skip_next_rounded,
                                          ),
                                          title: Text('Play next'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: _TrackAction.addToQueue,
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.playlist_add_rounded,
                                          ),
                                          title: Text('Add to queue'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: _TrackAction.addToPlaylist,
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.queue_music_rounded,
                                          ),
                                          title: Text('Add to playlist'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: _TrackAction.favorite,
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.favorite_border_rounded,
                                          ),
                                          title: Text('Toggle favorite'),
                                        ),
                                      ),
                                      PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: _TrackAction.removeFromLibrary,
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.remove_circle_outline_rounded,
                                          ),
                                          title: Text('Remove from library'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .08),
                    border: Border.all(color: scheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 17,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_download_outlined,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Text('Drop audio files or folders to add them'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _TrackAction {
  playNext,
  addToQueue,
  favorite,
  addToPlaylist,
  removeFromLibrary,
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 42, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
