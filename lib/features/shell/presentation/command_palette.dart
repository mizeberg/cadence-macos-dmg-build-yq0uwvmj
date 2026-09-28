import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../playback/application/playback_controller.dart';
import '../application/shell_state.dart';

class CommandPaletteDialog extends ConsumerWidget {
  const CommandPaletteDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = <_CommandItem>[
      _CommandItem(
        'Play / pause',
        Icons.play_arrow_rounded,
        () => unawaited(
          ref.read(playbackControllerProvider.notifier).togglePlayPause(),
        ),
      ),
      _CommandItem(
        'Next track',
        Icons.skip_next_rounded,
        () => unawaited(ref.read(playbackControllerProvider.notifier).next()),
      ),
      _CommandItem(
        'Previous track',
        Icons.skip_previous_rounded,
        () =>
            unawaited(ref.read(playbackControllerProvider.notifier).previous()),
      ),
      _CommandItem(
        'Shuffle',
        Icons.shuffle_rounded,
        () => ref.read(playbackControllerProvider.notifier).toggleShuffle(),
      ),
      _CommandItem(
        'Search',
        Icons.search_rounded,
        () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.search),
      ),
      _CommandItem(
        'Library',
        Icons.library_music_outlined,
        () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.library),
      ),
      _CommandItem(
        'Downloads',
        Icons.download_outlined,
        () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.downloads),
      ),
      _CommandItem(
        'Settings',
        Icons.settings_outlined,
        () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.settings),
      ),
      _CommandItem(
        'About Cadence',
        Icons.info_outline_rounded,
        () =>
            ref.read(destinationProvider.notifier).select(AppDestination.about),
      ),
    ];
    return AlertDialog(
      title: const Text('Command palette'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      content: SizedBox(
        width: 420,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: commands.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final command = commands[index];
            return ListTile(
              leading: Icon(command.icon),
              title: Text(command.label),
              onTap: () {
                Navigator.of(context).pop();
                command.action();
              },
            );
          },
        ),
      ),
    );
  }
}

class _CommandItem {
  const _CommandItem(this.label, this.icon, this.action);

  final String label;
  final IconData icon;
  final VoidCallback action;
}
