import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/presentation/song_list_tile.dart';
import '../application/playback_controller.dart';
import '../domain/playback_queue.dart';

class QueuePage extends ConsumerWidget {
  const QueuePage({required this.onOpenLibrary, super.key});
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final queue = state.queue;
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(playbackControllerProvider.notifier);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Up next',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${queue.songs.length} ${queue.songs.length == 1 ? 'track' : 'tracks'} · user-managed queue',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: queue.shuffled ? 'Turn shuffle off' : 'Shuffle queue',
                onPressed: queue.songs.length < 2
                    ? null
                    : controller.toggleShuffle,
                isSelected: queue.shuffled,
                icon: const Icon(Icons.shuffle_rounded),
              ),
              IconButton(
                tooltip: switch (queue.repeatMode) {
                  RepeatMode.off => 'Repeat off',
                  RepeatMode.all => 'Repeat queue',
                  RepeatMode.one => 'Repeat current track',
                },
                onPressed: queue.isEmpty ? null : controller.cycleRepeat,
                isSelected: queue.repeatMode != RepeatMode.off,
                icon: Icon(
                  queue.repeatMode == RepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: queue.isEmpty ? null : controller.clearQueue,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: queue.isEmpty
              ? _QueueEmptyState(onOpenLibrary: onOpenLibrary)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                  itemCount: queue.songs.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      controller.moveQueue(oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final song = queue.songs[index];
                    final active = index == queue.currentIndex;
                    return Row(
                      key: ValueKey('queue:$index:${song.id}'),
                      children: [
                        Expanded(
                          child: SongListTile(
                            song: song,
                            selected: active,
                            indexLabel: active && state.isPlaying
                                ? '▶'
                                : '${index + 1}',
                            onTap: () => controller.playQueue(
                              queue.songs,
                              startIndex: index,
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove from queue',
                              onPressed: () => controller.removeQueueAt(index),
                              icon: const Icon(Icons.close_rounded, size: 19),
                            ),
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _QueueEmptyState extends StatelessWidget {
  const _QueueEmptyState({required this.onOpenLibrary});
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_play_rounded, size: 46, color: scheme.primary),
            const SizedBox(height: 14),
            Text(
              'Your queue is empty',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              'Play a local track or add one to start building what comes next.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onOpenLibrary,
              icon: const Icon(Icons.library_music_outlined),
              label: const Text('Browse library'),
            ),
          ],
        ),
      ),
    );
  }
}
