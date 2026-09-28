import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repository_providers.dart';
import '../data/local_library_repository.dart';
import '../domain/song.dart';

final librarySortProvider = StateProvider<LibrarySort>(
  (ref) => LibrarySort.title,
);
final favoritesOnlyProvider = StateProvider<bool>((ref) => false);
final recentlyPlayedSongsProvider = FutureProvider<List<Song>>((ref) {
  return ref.watch(localLibraryRepositoryProvider).getRecentlyPlayed();
});

class LibraryQuery {
  const LibraryQuery({
    required this.query,
    this.sort = LibrarySort.title,
    this.favoritesOnly = false,
    this.limit = 5000,
  });

  final String query;
  final LibrarySort sort;
  final bool favoritesOnly;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      query == other.query &&
      sort == other.sort &&
      favoritesOnly == other.favoritesOnly &&
      limit == other.limit;

  @override
  int get hashCode => Object.hash(query, sort, favoritesOnly, limit);
}

final librarySearchResultsProvider =
    FutureProvider.family<List<Song>, LibraryQuery>(
      (ref, filters) => ref
          .watch(localLibraryRepositoryProvider)
          .getSongs(
            query: filters.query,
            sort: filters.sort,
            favoritesOnly: filters.favoritesOnly,
            limit: filters.limit,
          ),
    );
