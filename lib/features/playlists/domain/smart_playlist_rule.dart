import 'dart:convert';

enum SmartPlaylistSort { recentlyAdded, mostPlayed, highestRated, title }

class SmartPlaylistRule {
  const SmartPlaylistRule({
    this.favoritesOnly = false,
    this.losslessOnly = false,
    this.minimumRating,
    this.minimumPlayCount,
    this.addedWithinDays,
    this.genre,
    this.sort = SmartPlaylistSort.recentlyAdded,
    this.limit = 200,
  });

  final bool favoritesOnly;
  final bool losslessOnly;
  final int? minimumRating;
  final int? minimumPlayCount;
  final int? addedWithinDays;
  final String? genre;
  final SmartPlaylistSort sort;
  final int limit;

  Map<String, Object?> toMap() => {
    'version': 1,
    'favoritesOnly': favoritesOnly,
    'losslessOnly': losslessOnly,
    'minimumRating': minimumRating,
    'minimumPlayCount': minimumPlayCount,
    'addedWithinDays': addedWithinDays,
    'genre': _normalizedGenre,
    'sort': sort.name,
    'limit': limit.clamp(1, 1000),
  };

  String encode() => jsonEncode(toMap());

  String? get _normalizedGenre {
    final value = genre?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  factory SmartPlaylistRule.decode(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) {
      return const SmartPlaylistRule();
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Smart-playlist rules must be a JSON object.',
      );
    }
    final minimumRating = _optionalInt(decoded['minimumRating']);
    final minimumPlayCount = _optionalInt(decoded['minimumPlayCount']);
    final addedWithinDays = _optionalInt(decoded['addedWithinDays']);
    final limit = _optionalInt(decoded['limit']) ?? 200;
    final sortName = decoded['sort'] as String?;
    return SmartPlaylistRule(
      favoritesOnly: decoded['favoritesOnly'] == true,
      losslessOnly: decoded['losslessOnly'] == true,
      minimumRating: minimumRating?.clamp(1, 5).toInt(),
      minimumPlayCount: minimumPlayCount?.clamp(1, 1000000).toInt(),
      addedWithinDays: addedWithinDays?.clamp(1, 36500).toInt(),
      genre: decoded['genre'] as String?,
      sort: SmartPlaylistSort.values.firstWhere(
        (value) => value.name == sortName,
        orElse: () => SmartPlaylistSort.recentlyAdded,
      ),
      limit: limit.clamp(1, 1000),
    );
  }

  static int? _optionalInt(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => null,
  };
}
