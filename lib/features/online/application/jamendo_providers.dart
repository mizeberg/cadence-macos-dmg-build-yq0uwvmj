import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/database/settings_repository_provider.dart';
import '../../library/domain/song.dart';
import '../data/jamendo_client.dart';

const jamendoClientIdSettingKey = 'online.jamendo.client_id';

final jamendoClientIdProvider = FutureProvider<String?>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .getString(jamendoClientIdSettingKey);
});

final jamendoClientProvider = Provider<JamendoClient>((ref) {
  final httpClient = http.Client();
  ref.onDispose(httpClient.close);
  return JamendoClient(client: httpClient);
});

/// Searches after a short quiet period so typing in the global search field
/// does not send a request for every keystroke. Disposed queries are dropped.
final jamendoSearchResultsProvider = FutureProvider.autoDispose
    .family<List<Song>, String>((ref, query) async {
      final normalized = query.trim();
      if (normalized.length < 2) return const [];

      var disposed = false;
      final debounce = Completer<void>();
      final timer = Timer(const Duration(milliseconds: 450), () {
        if (!debounce.isCompleted) debounce.complete();
      });
      ref.onDispose(() {
        disposed = true;
        timer.cancel();
        if (!debounce.isCompleted) debounce.complete();
      });
      await debounce.future;
      if (disposed) return const [];

      final clientId = await ref.watch(jamendoClientIdProvider.future);
      if (disposed || clientId == null || clientId.trim().isEmpty) {
        return const [];
      }
      final tracks = await ref
          .watch(jamendoClientProvider)
          .searchTracks(clientId: clientId, query: normalized);
      return tracks.map((track) => track.toSong()).toList(growable: false);
    });
