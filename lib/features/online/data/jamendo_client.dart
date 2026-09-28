import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/jamendo_track.dart';

class JamendoClient {
  JamendoClient({required this.client});

  static final Uri _endpoint = Uri.https('api.jamendo.com', '/v3.0/tracks/');

  final http.Client client;

  Future<List<JamendoTrack>> searchTracks({
    required String clientId,
    required String query,
    int limit = 40,
  }) async {
    final normalizedQuery = query.trim();
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      throw ArgumentError.value(clientId, 'clientId', 'Cannot be empty.');
    }
    if (normalizedQuery.length < 2) return const [];

    final uri = _endpoint.replace(
      queryParameters: {
        'client_id': normalizedClientId,
        'format': 'json',
        'limit': '${limit.clamp(1, 100)}',
        'search': normalizedQuery,
        'audioformat': 'mp32',
        'imagesize': '200',
        'include': 'licenses',
      },
    );
    final response = await client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw JamendoApiException(
        'Jamendo returned HTTP ${response.statusCode}.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const JamendoApiException('Jamendo returned invalid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const JamendoApiException(
        'Jamendo returned an unexpected response.',
      );
    }

    final headers = decoded['headers'];
    if (headers is Map && headers['status'] is String) {
      final status = (headers['status'] as String).toLowerCase();
      if (status != 'success') {
        final message = headers['error_message']?.toString().trim();
        throw JamendoApiException(
          message == null || message.isEmpty
              ? 'Jamendo could not complete this search.'
              : message,
        );
      }
    }
    final results = decoded['results'];
    if (results is! List) {
      throw const JamendoApiException('Jamendo returned no track list.');
    }

    final tracks = <JamendoTrack>[];
    for (final item in results) {
      if (item is! Map) continue;
      try {
        final track = JamendoTrack.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
        tracks.add(track);
      } on FormatException {
        // Skip malformed or non-streamable rows rather than failing a search.
      }
    }
    return tracks;
  }
}

class JamendoApiException implements Exception {
  const JamendoApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
