import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repository_providers.dart';
import '../../library/domain/song.dart';
import '../domain/playlist.dart';

final playlistsProvider = FutureProvider<List<Playlist>>((ref) {
  return ref.watch(playlistRepositoryProvider).getAll();
});

final playlistTracksProvider = FutureProvider.family<List<Song>, String>((
  ref,
  id,
) {
  return ref.watch(playlistRepositoryProvider).getTracks(id);
});
