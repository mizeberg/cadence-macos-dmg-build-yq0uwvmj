import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/repository_providers.dart';
import '../../library/application/library_search_providers.dart';
import '../../library/domain/song.dart';
import '../../library/presentation/song_list_tile.dart';
import '../../online/application/jamendo_providers.dart';
import '../../playback/application/playback_controller.dart';
import '../../shell/application/shell_state.dart';

final recentSearchesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(localLibraryRepositoryProvider).getRecentSearches();
});

enum _SearchScope { library, online }

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  _SearchScope _scope = _SearchScope.library;

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider).trim();
    final scheme = Theme.of(context).colorScheme;
    final localResults = ref.watch(
      librarySearchResultsProvider(LibraryQuery(query: query, limit: 5000)),
    );
    final recents = ref.watch(recentSearchesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.5),
              ),
              const SizedBox(height: 5),
              Text(
                'Find music in your library or discover independent artists online.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              SegmentedButton<_SearchScope>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _SearchScope.library,
                    label: Text('My library'),
                    icon: Icon(Icons.library_music_outlined),
                  ),
                  ButtonSegment(
                    value: _SearchScope.online,
                    label: Text('Online catalog'),
                    icon: Icon(Icons.public_rounded),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (value) =>
                    setState(() => _scope = value.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: _scope == _SearchScope.library
              ? _buildLocalResults(context, localResults, recents, query)
              : _buildOnlineResults(context, query),
        ),
      ],
    );
  }

  Widget _buildLocalResults(
    BuildContext context,
    AsyncValue<List<Song>> results,
    AsyncValue<List<String>> recents,
    String query,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final songs = results.valueOrNull ?? const <Song>[];
    if (query.isEmpty) {
      return recents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Recent searches are unavailable.')),
        data: (items) => items.isEmpty
            ? _emptyState(
                context,
                icon: Icons.search_rounded,
                title: 'Your library search starts here',
                subtitle: 'Use the search field above to find local tracks.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(30, 0, 30, 24),
                children: [
                  Text(
                    'RECENT SEARCHES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final item in items)
                    ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: Text(item),
                      trailing: Icon(
                        Icons.north_west_rounded,
                        size: 17,
                        color: scheme.onSurfaceVariant,
                      ),
                      onTap: () =>
                          ref.read(searchQueryProvider.notifier).update(item),
                    ),
                ],
              ),
      );
    }

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          const Center(child: Text('Search could not reach the local index.')),
      data: (items) => items.isEmpty
          ? _emptyState(
              context,
              icon: Icons.search_off_rounded,
              title: 'No tracks found',
              subtitle: 'Try another title, artist, album, or genre.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${items.length} local results for “$query”',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: songs.isEmpty
                            ? null
                            : () => ref
                                  .read(playbackControllerProvider.notifier)
                                  .playQueue(songs),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play results'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 2),
                    itemBuilder: (context, index) => SongListTile(
                      song: items[index],
                      onTap: () => ref
                          .read(playbackControllerProvider.notifier)
                          .playQueue(items, startIndex: index),
                      trailing: IconButton(
                        tooltip: 'Add to queue',
                        onPressed: () => ref
                            .read(playbackControllerProvider.notifier)
                            .addToQueue(items[index]),
                        icon: const Icon(Icons.playlist_add_rounded),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOnlineResults(BuildContext context, String query) {
    final scheme = Theme.of(context).colorScheme;
    final clientId = ref.watch(jamendoClientIdProvider);
    return clientId.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _emptyState(
        context,
        icon: Icons.cloud_off_outlined,
        title: 'Online catalog settings are unavailable',
        subtitle: 'Restart Cadence and try again.',
      ),
      data: (id) {
        if (id == null || id.trim().isEmpty) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.public_rounded,
                        size: 42,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Connect the online catalog',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add a free Jamendo developer Client ID in Settings to search and stream its Creative Commons catalog.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.tonalIcon(
                        onPressed: () => ref
                            .read(destinationProvider.notifier)
                            .select(AppDestination.settings),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Open Settings'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (query.length < 2) {
          return _emptyState(
            context,
            icon: Icons.travel_explore_rounded,
            title: 'Discover independent music',
            subtitle: 'Type at least two characters in the search field above.',
          );
        }

        final results = ref.watch(jamendoSearchResultsProvider(query));
        return results.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _emptyState(
            context,
            icon: Icons.cloud_off_outlined,
            title: 'Online search failed',
            subtitle: _friendlyError(error),
          ),
          data: (songs) => songs.isEmpty
              ? _emptyState(
                  context,
                  icon: Icons.search_off_rounded,
                  title: 'No online tracks found',
                  subtitle: 'Try a different search term.',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 0, 30, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${songs.length} Jamendo results for “$query” · streamed online',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: songs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return SongListTile(
                            song: song,
                            onTap: () => ref
                                .read(playbackControllerProvider.notifier)
                                .playQueue(songs, startIndex: index),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Add to queue',
                                  onPressed: () => ref
                                      .read(playbackControllerProvider.notifier)
                                      .addToQueue(song),
                                  icon: const Icon(Icons.playlist_add_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Open track on Jamendo',
                                  onPressed: song.sourceUrl == null
                                      ? null
                                      : () => _openLink(song.sourceUrl!),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                ),
                                if (song.licenseUrl != null)
                                  IconButton(
                                    tooltip: 'Open Creative Commons license',
                                    onPressed: () =>
                                        _openLink(song.licenseUrl!),
                                    icon: const Icon(
                                      Icons.description_outlined,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: scheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('JamendoApiException: ', '');
    if (message.toLowerCase().contains('client') ||
        message.toLowerCase().contains('credential')) {
      return 'Check the Jamendo Client ID in Settings. $message';
    }
    return message;
  }
}
