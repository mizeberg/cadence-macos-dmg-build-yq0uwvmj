import 'dart:convert';

import 'package:cadence_music/features/online/data/jamendo_client.dart';
import 'package:cadence_music/features/online/domain/jamendo_track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('maps official API track fields to an online playback item', () {
    final track = JamendoTrack.fromJson({
      'id': 42,
      'name': 'Open Road',
      'artist_name': 'North Shore',
      'album_name': 'Wide Skies',
      'duration': 193,
      'audio': 'https://audio.example.test/open-road.mp3',
      'image': 'https://images.example.test/cover.jpg',
      'shareurl': 'https://www.jamendo.com/track/42',
      'license_ccurl': 'https://creativecommons.org/licenses/by/4.0/',
    });

    final song = track.toSong();
    expect(song.id, 'jamendo:42');
    expect(song.path, 'https://audio.example.test/open-road.mp3');
    expect(song.title, 'Open Road');
    expect(song.displayArtist, 'North Shore');
    expect(song.duration.inSeconds, 193);
    expect(song.sourceName, 'Jamendo');
    expect(song.sourceUrl, 'https://www.jamendo.com/track/42');
    expect(song.licenseLabel, 'CC BY 4.0');
    expect(song.artworkPath, 'https://images.example.test/cover.jpg');
    expect(song.isOnline, isTrue);
  });

  test('rejects non-HTTPS playback URLs', () {
    expect(
      () => JamendoTrack.fromJson({
        'id': '1',
        'name': 'Track',
        'artist_name': 'Artist',
        'audio': 'http://audio.example.test/track.mp3',
      }),
      throwsFormatException,
    );
  });

  test('search uses the official endpoint and skips malformed rows', () async {
    Uri? requested;
    final client = JamendoClient(
      client: MockClient((request) async {
        requested = request.url;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'headers': {'status': 'success'},
              'results': [
                {
                  'id': '7',
                  'name': 'Glass Harbor',
                  'artist_name': 'Juniper',
                  'duration': 120,
                  'audio': 'https://audio.example.test/track.mp3',
                  'shareurl': 'https://www.jamendo.com/track/7',
                  'license_ccurl':
                      'https://creativecommons.org/licenses/by-sa/4.0/',
                },
                {'id': 'incomplete'},
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final tracks = await client.searchTracks(
      clientId: 'public-client-id',
      query: '  glass harbor  ',
      limit: 25,
    );

    expect(requested!.scheme, 'https');
    expect(requested!.host, 'api.jamendo.com');
    expect(requested!.path, '/v3.0/tracks/');
    expect(requested!.queryParameters['client_id'], 'public-client-id');
    expect(requested!.queryParameters['search'], 'glass harbor');
    expect(requested!.queryParameters['limit'], '25');
    expect(requested!.queryParameters['audioformat'], 'mp32');
    expect(requested!.queryParameters['include'], 'licenses');
    expect(tracks, hasLength(1));
    expect(tracks.single.licenseLabel, 'CC BY-SA 4.0');
  });

  test(
    'reports API errors and does not issue a request for short queries',
    () async {
      var requests = 0;
      final client = JamendoClient(
        client: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'headers': {
                'status': 'failed',
                'error_message': 'invalid client id',
              },
              'results': [],
            }),
            200,
          );
        }),
      );

      expect(await client.searchTracks(clientId: 'id', query: 'a'), isEmpty);
      expect(requests, 0);
      await expectLater(
        client.searchTracks(clientId: 'id', query: 'music'),
        throwsA(isA<JamendoApiException>()),
      );
    },
  );
}
