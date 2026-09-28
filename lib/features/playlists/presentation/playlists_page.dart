import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repository_providers.dart';
import '../../library/domain/song.dart';
import '../../library/presentation/song_list_tile.dart';
import '../../playback/application/playback_controller.dart';
import '../application/playlist_providers.dart';
import '../domain/playlist.dart';
import '../domain/smart_playlist_rule.dart';
import 'smart_playlist_dialog.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create playlist'),
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
    if (title == null || title.trim().isEmpty || !context.mounted) return;
    try {
      await ref.read(playlistRepositoryProvider).create(title);
      ref.invalidate(playlistsProvider);
    } on ArgumentError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a playlist name up to 100 characters.'),
        ),
      );
    }
  }

  Future<void> _createSmartPlaylist(BuildContext context, WidgetRef ref) async {
    final draft = await showSmartPlaylistDialog(context);
    if (draft == null || !context.mounted || draft.title == null) return;
    try {
      await ref
          .read(playlistRepositoryProvider)
          .createSmart(draft.title!, draft.rule);
      ref.invalidate(playlistsProvider);
    } on ArgumentError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a playlist name up to 100 characters.'),
        ),
      );
    }
  }

  Future<void> _deletePlaylist(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          '“${playlist.title}” will be removed. Your audio files will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete playlist'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(playlistRepositoryProvider).delete(playlist.id);
      ref.invalidate(playlistsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Playlists',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your mixes stay on this device.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _createSmartPlaylist(context, ref),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Smart playlist'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _createPlaylist(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New playlist'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: playlists.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: FilledButton.tonal(
                onPressed: () => ref.invalidate(playlistsProvider),
                child: const Text('Retry loading playlists'),
              ),
            ),
            data: (items) => items.isEmpty
                ? _PlaylistEmptyState(
                    onCreate: () => _createPlaylist(context, ref),
                    onCreateSmart: () => _createSmartPlaylist(context, ref),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1080
                          ? 3
                          : constraints.maxWidth >= 650
                          ? 2
                          : 1;
                      if (columns == 1) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 26),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _PlaylistCard(
                            playlist: items[index],
                            onOpen: () => _open(context, items[index]),
                            onDelete: () =>
                                _deletePlaylist(context, ref, items[index]),
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(26, 4, 26, 28),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 134,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _PlaylistCard(
                          playlist: items[index],
                          onOpen: () => _open(context, items[index]),
                          onDelete: () =>
                              _deletePlaylist(context, ref, items[index]),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailPage(playlist: playlist),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.onOpen,
    required this.onDelete,
  });
  final Playlist playlist;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: .25),
                      scheme.tertiary.withValues(alpha: .16),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  playlist.isSmart
                      ? Icons.auto_awesome_rounded
                      : Icons.queue_music_rounded,
                  size: 27,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            playlist.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (playlist.isSmart)
                          Text(
                            'SMART',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: scheme.primary,
                                  letterSpacing: .5,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.trackCount} ${playlist.trackCount == 1 ? 'track' : 'tracks'} · ${_duration(playlist.duration)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpen,
                tooltip: 'Open playlist',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: 'Playlist actions',
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete playlist'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _duration(Duration duration) {
    if (duration <= Duration.zero) return '0 min';
    final minutes = duration.inMinutes;
    return '$minutes min';
  }
}

class _PlaylistEmptyState extends StatelessWidget {
  const _PlaylistEmptyState({
    required this.onCreate,
    required this.onCreateSmart,
  });
  final VoidCallback onCreate;
  final VoidCallback onCreateSmart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded, size: 42, color: scheme.primary),
            const SizedBox(height: 14),
            Text(
              'Make a playlist of your own',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              'Group tracks from your local library into playlists that stay offline.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create playlist'),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onCreateSmart,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Create smart playlist'),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaylistDetailPage extends ConsumerWidget {
  const PlaylistDetailPage({required this.playlist, super.key});
  final Playlist playlist;

  Future<void> _addTracks(BuildContext context, WidgetRef ref) async {
    if (playlist.isSmart) return;
    final allSongs = await ref
        .read(localLibraryRepositoryProvider)
        .getSongs(limit: 5000);
    if (!context.mounted) return;
    final selectedIds = <String>{};
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add tracks'),
          content: SizedBox(
            width: 520,
            height: 430,
            child: allSongs.isEmpty
                ? const Center(child: Text('Add music to your library first.'))
                : ListView.builder(
                    itemCount: allSongs.length,
                    itemBuilder: (context, index) {
                      final song = allSongs[index];
                      return CheckboxListTile(
                        value: selectedIds.contains(song.id),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.displayArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) => setDialogState(() {
                          if (value == true) {
                            selectedIds.add(song.id);
                          } else {
                            selectedIds.remove(song.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text('Add ${selectedIds.length}'),
            ),
          ],
        ),
      ),
    );
    if (added == true && context.mounted) {
      await ref
          .read(playlistRepositoryProvider)
          .addTracks(playlist.id, selectedIds);
      ref.invalidate(playlistTracksProvider(playlist.id));
      ref.invalidate(playlistsProvider);
    }
  }

  Future<void> _editSmartRules(BuildContext context, WidgetRef ref) async {
    final draft = await showSmartPlaylistDialog(
      context,
      initialTitle: playlist.title,
      initialRule: playlist.smartRule ?? const SmartPlaylistRule(),
    );
    if (draft == null || !context.mounted) return;
    await ref
        .read(playlistRepositoryProvider)
        .updateSmartRule(playlist.id, draft.rule);
    ref.invalidate(playlistTracksProvider(playlist.id));
    ref.invalidate(playlistsProvider);
  }

  Widget _trackRow(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    int index, {
    required bool allowEdits,
  }) {
    final song = songs[index];
    return Row(
      key: ValueKey('${playlist.id}:${song.id}'),
      children: [
        Expanded(
          child: SongListTile(
            song: song,
            indexLabel: '${index + 1}',
            onTap: () => ref
                .read(playbackControllerProvider.notifier)
                .playQueue(songs, startIndex: index),
            trailing: allowEdits
                ? IconButton(
                    tooltip: 'Remove from playlist',
                    onPressed: () async {
                      await ref
                          .read(playlistRepositoryProvider)
                          .removeTrackAt(playlist.id, index);
                      ref.invalidate(playlistTracksProvider(playlist.id));
                      ref.invalidate(playlistsProvider);
                    },
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 19,
                    ),
                  )
                : null,
          ),
        ),
        if (allowEdits)
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.drag_handle_rounded),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(playlistTracksProvider(playlist.id));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.title),
        actions: [
          if (playlist.isSmart)
            IconButton(
              tooltip: 'Edit smart playlist rules',
              onPressed: () => _editSmartRules(context, ref),
              icon: const Icon(Icons.tune_rounded),
            )
          else
            IconButton(
              tooltip: 'Add tracks',
              onPressed: () => _addTracks(context, ref),
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: tracks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not load this playlist.')),
        data: (songs) => songs.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_note_outlined,
                        size: 40,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        playlist.isSmart
                            ? 'No tracks match these rules'
                            : 'This playlist is empty',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      if (playlist.isSmart)
                        FilledButton.tonalIcon(
                          onPressed: () => _editSmartRules(context, ref),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Edit rules'),
                        )
                      else
                        FilledButton.tonalIcon(
                          onPressed: () => _addTracks(context, ref),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add tracks'),
                        ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
                    child: Row(
                      children: [
                        Text(
                          '${songs.length} ${songs.length == 1 ? 'track' : 'tracks'}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: () => ref
                              .read(playbackControllerProvider.notifier)
                              .playQueue(songs),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play playlist'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: playlist.isSmart
                        ? ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                            itemCount: songs.length,
                            itemBuilder: (context, index) => _trackRow(
                              context,
                              ref,
                              songs,
                              index,
                              allowEdits: false,
                            ),
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                            itemCount: songs.length,
                            onReorderItem: (oldIndex, newIndex) async {
                              await ref
                                  .read(playlistRepositoryProvider)
                                  .reorderTrack(
                                    playlist.id,
                                    oldIndex,
                                    newIndex,
                                  );
                              ref.invalidate(
                                playlistTracksProvider(playlist.id),
                              );
                              ref.invalidate(playlistsProvider);
                            },
                            itemBuilder: (context, index) => _trackRow(
                              context,
                              ref,
                              songs,
                              index,
                              allowEdits: true,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
