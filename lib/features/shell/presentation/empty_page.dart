import 'package:flutter/material.dart';

import '../application/shell_state.dart';

class EmptyPage extends StatelessWidget {
  const EmptyPage({
    required this.destination,
    required this.query,
    required this.onOpenLibrary,
    super.key,
  });

  final AppDestination destination;
  final String query;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final content = _content(destination, query);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 530),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .12),
                  ),
                ),
                child: Icon(content.icon, size: 31, color: scheme.primary),
              ),
              const SizedBox(height: 22),
              Text(
                content.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.4),
              ),
              const SizedBox(height: 10),
              Text(
                content.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: .7),
                  ),
                ),
                child: Text(
                  content.status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: .25,
                  ),
                ),
              ),
              if (content.showLibraryAction) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: onOpenLibrary,
                  icon: const Icon(Icons.library_music_outlined),
                  label: const Text('Go to your library'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static _EmptyContent _content(
    AppDestination destination,
    String query,
  ) => switch (destination) {
    AppDestination.explore => const _EmptyContent(
      Icons.explore_outlined,
      'No music sources yet',
      'Explore becomes available when you connect a supported, terms-compliant source. Local music will remain available offline.',
      'SOURCE CONNECTIONS · PLANNED',
    ),
    AppDestination.library => const _EmptyContent(
      Icons.library_music_outlined,
      'Your library is empty',
      'Add a local music folder to build your collection. Folder selection, metadata indexing, and artwork are the next implementation milestone.',
      'LOCAL IMPORT · NEXT MILESTONE',
    ),
    AppDestination.playlists => const _EmptyContent(
      Icons.queue_music_rounded,
      'Your playlists start here',
      'Once your local library is indexed, you can group tracks into playlists that stay on this device.',
      'PLAYLISTS · PLANNED',
      showLibraryAction: true,
    ),
    AppDestination.queue => const _EmptyContent(
      Icons.playlist_play_rounded,
      'Nothing in the queue',
      'Your upcoming tracks will appear here after the playback engine and local library are connected.',
      'PLAYBACK ENGINE · PLANNED',
      showLibraryAction: true,
    ),
    AppDestination.downloads => const _EmptyContent(
      Icons.download_outlined,
      'No downloads',
      'Downloads require a supported provider and will only be available when permitted by that source’s terms.',
      'COMPLIANT SOURCES · PLANNED',
    ),
    AppDestination.search => _EmptyContent(
      Icons.search_rounded,
      query.isEmpty ? 'Search your library' : 'No indexed music to search',
      query.isEmpty
          ? 'Type a track, album, or artist above. Search will cover your indexed local collection.'
          : '“$query” has no matches because no local folders have been indexed yet.',
      'LOCAL SEARCH · PLANNED',
      showLibraryAction: true,
    ),
    _ => const _EmptyContent(
      Icons.music_note_rounded,
      'Nothing to show yet',
      'This area will fill in when the related feature is implemented.',
      'IN DEVELOPMENT',
    ),
  };
}

class _EmptyContent {
  const _EmptyContent(
    this.icon,
    this.title,
    this.message,
    this.status, {
    this.showLibraryAction = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final String status;
  final bool showLibraryAction;
}
