import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/data/local_library_repository.dart';
import '../../features/playlists/data/playlist_repository.dart';
import 'database_provider.dart';

final localLibraryRepositoryProvider = Provider<LocalLibraryRepository>(
  (ref) => LocalLibraryRepository(ref.watch(appDatabaseProvider).connection),
);

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => PlaylistRepository(ref.watch(appDatabaseProvider).connection),
);
