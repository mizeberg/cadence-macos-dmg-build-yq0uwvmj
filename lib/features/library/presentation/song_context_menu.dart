import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repository_providers.dart';
import '../../playback/application/playback_controller.dart';
import '../../playlists/application/playlist_providers.dart';
import '../../shell/application/shell_state.dart';
import '../application/library_controller.dart';
import '../application/library_search_providers.dart';
import '../domain/song.dart';
import 'audio_info_dialog.dart';

class SongContextMenu extends ConsumerWidget {
  const SongContextMenu({required this.song, super.key});
  final Song song;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => PopupMenuButton<_SongAction>(
    tooltip: 'Track actions',
    icon: const Icon(Icons.more_horiz_rounded),
    onSelected: (action) => _perform(context, ref, action),
    itemBuilder: (context) => [
      _item(_SongAction.play, Icons.play_arrow_rounded, 'Play'),
      _item(_SongAction.playNext, Icons.next_plan_rounded, 'Play next'),
      _item(_SongAction.addToQueue, Icons.queue_music_rounded, 'Add to queue'),
      _item(
        _SongAction.favorite,
        song.isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        song.isFavorite ? 'Remove from favorites' : 'Add to favorites',
      ),
      _item(
        _SongAction.addToPlaylist,
        Icons.playlist_add_rounded,
        'Add to playlist',
      ),
      _item(_SongAction.rate, Icons.star_outline_rounded, 'Set rating'),
      const PopupMenuDivider(),
      _item(_SongAction.artist, Icons.person_outline_rounded, 'Go to artist'),
      _item(_SongAction.album, Icons.album_outlined, 'Go to album'),
      _item(
        _SongAction.audioInfo,
        Icons.graphic_eq_rounded,
        'View audio information',
      ),
      _item(
        _SongAction.reveal,
        Icons.folder_open_rounded,
        'Open file location',
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<_SongAction>(
        enabled: false,
        child: Row(
          children: [
            Icon(Icons.download_outlined, size: 18),
            SizedBox(width: 12),
            Text('Download — no online source'),
          ],
        ),
      ),
      _item(
        _SongAction.remove,
        Icons.remove_circle_outline_rounded,
        'Remove from library',
      ),
    ],
  );

  static PopupMenuItem<_SongAction> _item(
    _SongAction action,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: action,
    child: Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)],
    ),
  );

  Future<void> _perform(
    BuildContext context,
    WidgetRef ref,
    _SongAction action,
  ) async {
    try {
      switch (action) {
        case _SongAction.play:
          await ref.read(playbackControllerProvider.notifier).playSong(song);
        case _SongAction.playNext:
          ref.read(playbackControllerProvider.notifier).playNext(song);
        case _SongAction.addToQueue:
          ref.read(playbackControllerProvider.notifier).addToQueue(song);
        case _SongAction.favorite:
          await ref
              .read(localLibraryRepositoryProvider)
              .setFavorite(song.id, !song.isFavorite);
          if (!context.mounted) return;
          _refresh(ref);
          _snack(
            context,
            song.isFavorite ? 'Removed from favorites.' : 'Added to favorites.',
          );
        case _SongAction.addToPlaylist:
          await _addToPlaylist(context, ref);
        case _SongAction.rate:
          await _rate(context, ref);
        case _SongAction.artist:
          ref.read(searchQueryProvider.notifier).update(song.displayArtist);
          ref.read(destinationProvider.notifier).select(AppDestination.search);
        case _SongAction.album:
          ref.read(searchQueryProvider.notifier).update(song.displayAlbum);
          ref.read(destinationProvider.notifier).select(AppDestination.search);
        case _SongAction.audioInfo:
          await showAudioInfoDialog(context, song);
        case _SongAction.reveal:
          await _revealInFileManager(context);
        case _SongAction.remove:
          await _removeFromLibrary(context, ref);
      }
    } catch (error) {
      if (context.mounted) _snack(context, 'Track action failed: $error');
    }
  }

  Future<void> _addToPlaylist(BuildContext context, WidgetRef ref) async {
    final playlists = await ref.read(playlistsProvider.future);
    if (!context.mounted) return;
    if (playlists.isEmpty) {
      _snack(context, 'Create a playlist before adding tracks.');
      return;
    }
    final playlistId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add to playlist'),
        children: [
          for (final playlist in playlists)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, playlist.id),
              child: Text(playlist.title),
            ),
        ],
      ),
    );
    if (playlistId == null || !context.mounted) return;
    await ref.read(playlistRepositoryProvider).addTrack(playlistId, song.id);
    if (!context.mounted) return;
    ref.invalidate(playlistsProvider);
    ref.invalidate(playlistTracksProvider(playlistId));
    _snack(context, 'Added to playlist.');
  }

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    final rating = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Rate this track'),
        children: [
          for (var value = 0; value <= 5; value++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Row(
                children: [
                  Icon(
                    value == 0
                        ? Icons.remove_circle_outline
                        : Icons.star_rounded,
                  ),
                  const SizedBox(width: 10),
                  Text(value == 0 ? 'Clear rating' : '$value / 5'),
                ],
              ),
            ),
        ],
      ),
    );
    if (rating == null || !context.mounted) return;
    await ref.read(localLibraryRepositoryProvider).setRating(song.id, rating);
    _refresh(ref);
  }

  Future<void> _revealInFileManager(BuildContext context) async {
    final file = File(song.path);
    if (!await file.exists()) {
      if (context.mounted) {
        _snack(context, 'The audio file is no longer available.');
      }
      return;
    }
    if (Platform.isMacOS) {
      await Process.start('open', [
        '-R',
        song.path,
      ], mode: ProcessStartMode.detached);
    } else if (Platform.isWindows) {
      await Process.start('explorer.exe', [
        '/select,${song.path}',
      ], mode: ProcessStartMode.detached);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [
        file.parent.path,
      ], mode: ProcessStartMode.detached);
    } else {
      throw UnsupportedError(
        'File manager actions are available on desktop platforms.',
      );
    }
  }

  Future<void> _removeFromLibrary(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from library?'),
        content: Text(
          '“${song.title}” will be removed from Cadence. The audio file on disk will not be deleted.',
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
    if (confirmed != true || !context.mounted) return;
    await ref.read(localLibraryRepositoryProvider).removeSong(song.id);
    _refresh(ref);
  }

  static void _refresh(WidgetRef ref) {
    ref.invalidate(librarySearchResultsProvider);
    ref.invalidate(recentlyPlayedSongsProvider);
    ref.invalidate(libraryControllerProvider);
  }

  static void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _SongAction {
  play,
  playNext,
  addToQueue,
  favorite,
  addToPlaylist,
  rate,
  artist,
  album,
  audioInfo,
  reveal,
  remove,
}
