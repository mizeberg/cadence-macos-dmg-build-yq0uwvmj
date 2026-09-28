import 'dart:io';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/domain/song.dart';
import '../../library/presentation/song_list_tile.dart';
import '../application/playback_controller.dart';
import '../data/lyrics_provider.dart';
import '../domain/playback_queue.dart';

class NowPlayingDialog extends ConsumerStatefulWidget {
  const NowPlayingDialog({super.key});

  @override
  ConsumerState<NowPlayingDialog> createState() => _NowPlayingDialogState();
}

class _NowPlayingDialogState extends ConsumerState<NowPlayingDialog> {
  _PlayerPanel _panel = _PlayerPanel.upNext;

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackControllerProvider);
    final song = playback.currentSong;
    final scheme = Theme.of(context).colorScheme;
    final availableHeight = MediaQuery.sizeOf(context).height - 44;
    final height = availableHeight.clamp(600.0, 730.0);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 760,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 14, 10),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Now playing',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close player',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: song == null
                  ? _NoCurrentTrack(onClose: () => Navigator.pop(context))
                  : _PlayerContent(
                      song: song,
                      panel: _panel,
                      onPanelChanged: (value) => setState(() => _panel = value),
                    ),
            ),
            if (playback.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                color: scheme.errorContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: scheme.onErrorContainer,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        playback.error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerContent extends ConsumerWidget {
  const _PlayerContent({
    required this.song,
    required this.panel,
    required this.onPanelChanged,
  });
  final Song song;
  final _PlayerPanel panel;
  final ValueChanged<_PlayerPanel> onPanelChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final available = MediaQuery.sizeOf(context).height;
    final artSize = (available * .32).clamp(180.0, 270.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 17, 30, 20),
      child: Column(
        children: [
          Container(
            width: artSize,
            height: artSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: .25),
                  scheme.tertiary.withValues(alpha: .15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: song.artworkPath == null
                ? Icon(
                    Icons.music_note_rounded,
                    size: 76,
                    color: scheme.primary,
                  )
                : Image.file(
                    File(song.artworkPath!),
                    fit: BoxFit.cover,
                    cacheWidth: 620,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.music_note_rounded,
                      size: 76,
                      color: scheme.primary,
                    ),
                  ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${song.displayArtist} · ${song.displayAlbum}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (state.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: state.duration.inMilliseconds <= 0
                  ? 0
                  : state.position.inMilliseconds
                        .clamp(0, state.duration.inMilliseconds)
                        .toDouble(),
              max: state.duration.inMilliseconds > 0
                  ? state.duration.inMilliseconds.toDouble()
                  : 1,
              onChanged: state.duration > Duration.zero
                  ? (value) =>
                        controller.seek(Duration(milliseconds: value.round()))
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  _time(state.position),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  _time(state.duration),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: state.queue.shuffled ? 'Turn shuffle off' : 'Shuffle',
                onPressed: state.queue.songs.length < 2
                    ? null
                    : controller.toggleShuffle,
                isSelected: state.queue.shuffled,
                icon: const Icon(Icons.shuffle_rounded),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Previous track',
                onPressed: state.queue.songs.length < 2
                    ? null
                    : controller.previous,
                icon: const Icon(Icons.skip_previous_rounded, size: 31),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: state.isLoading ? null : controller.togglePlayPause,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(15),
                ),
                child: Icon(
                  state.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 29,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Next track',
                onPressed: state.queue.songs.length < 2
                    ? null
                    : controller.next,
                icon: const Icon(Icons.skip_next_rounded, size: 31),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: switch (state.queue.repeatMode) {
                  RepeatMode.off => 'Repeat off',
                  RepeatMode.all => 'Repeat queue',
                  RepeatMode.one => 'Repeat this track',
                },
                onPressed: state.queue.isEmpty ? null : controller.cycleRepeat,
                isSelected: state.queue.repeatMode != RepeatMode.off,
                icon: Icon(
                  state.queue.repeatMode == RepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                state.volume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_down_rounded,
                size: 19,
                color: scheme.onSurfaceVariant,
              ),
              Expanded(
                child: Slider(
                  value: state.volume,
                  onChanged: controller.setVolume,
                  max: 1,
                ),
              ),
              Icon(
                Icons.volume_up_rounded,
                size: 19,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 3),
          SegmentedButton<_PlayerPanel>(
            segments: const [
              ButtonSegment(
                value: _PlayerPanel.upNext,
                icon: Icon(Icons.queue_music_rounded),
                label: Text('Up next'),
              ),
              ButtonSegment(
                value: _PlayerPanel.lyrics,
                icon: Icon(Icons.lyrics_outlined),
                label: Text('Lyrics'),
              ),
            ],
            selected: {panel},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onPanelChanged(selection.first),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: panel == _PlayerPanel.upNext
                ? const _UpcomingTracks()
                : _LyricsPanel(song: song),
          ),
        ],
      ),
    );
  }

  static String _time(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _UpcomingTracks extends ConsumerWidget {
  const _UpcomingTracks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(
      playbackControllerProvider.select((state) => state.queue),
    );
    final controller = ref.read(playbackControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    if (queue.songs.length < 2) {
      return Center(
        child: Text(
          'Add tracks from your library to build a queue.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    final upcomingCount = (queue.songs.length - queue.currentIndex - 1).clamp(
      0,
      4,
    );
    final visible = queue.songs
        .skip(queue.currentIndex + 1)
        .take(upcomingCount)
        .toList();
    if (visible.isEmpty) {
      return Center(
        child: Text(
          queue.repeatMode == RepeatMode.all
              ? 'The queue will repeat after this track.'
              : 'You’re at the end of the queue.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) => SongListTile(
        song: visible[index],
        compact: true,
        onTap: () => controller.playQueue(
          queue.songs,
          startIndex: queue.currentIndex + 1 + index,
        ),
      ),
    );
  }
}

class _LyricsPanel extends ConsumerWidget {
  const _LyricsPanel({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(songLyricsProvider(song));
    final scheme = Theme.of(context).colorScheme;
    return lyrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          const Center(child: Text('Could not read local lyrics.')),
      data: (result) => result == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No local lyrics found. Cadence checks embedded audio tags and adjacent .lrc files. Online lyric providers are not connected.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                Text(
                  result.source,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  result.text,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(height: 1.6),
                ),
              ],
            ),
    );
  }
}

class _NoCurrentTrack extends StatelessWidget {
  const _NoCurrentTrack({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.music_off_rounded, size: 46),
        const SizedBox(height: 14),
        const Text('Nothing is playing yet'),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: onClose, child: const Text('Close')),
      ],
    ),
  );
}

enum _PlayerPanel { upNext, lyrics }
