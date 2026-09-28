import 'smart_playlist_rule.dart';

class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.description,
    this.artworkPath,
    this.trackCount = 0,
    this.durationMillis = 0,
    this.isSmart = false,
    this.smartRule,
  });

  final String id;
  final String title;
  final String? description;
  final String? artworkPath;
  final int createdAtMillis;
  final int updatedAtMillis;
  final int trackCount;
  final int durationMillis;
  final bool isSmart;
  final SmartPlaylistRule? smartRule;

  Duration get duration => Duration(milliseconds: durationMillis);

  Playlist copyWith({int? trackCount, int? durationMillis}) => Playlist(
    id: id,
    title: title,
    description: description,
    artworkPath: artworkPath,
    createdAtMillis: createdAtMillis,
    updatedAtMillis: updatedAtMillis,
    trackCount: trackCount ?? this.trackCount,
    durationMillis: durationMillis ?? this.durationMillis,
    isSmart: isSmart,
    smartRule: smartRule,
  );

  factory Playlist.fromDatabaseMap(Map<String, Object?> row) => Playlist(
    id: row['id']! as String,
    title: row['title']! as String,
    description: row['description'] as String?,
    artworkPath: row['artwork_path'] as String?,
    createdAtMillis: _asInt(row['created_at']) ?? 0,
    updatedAtMillis: _asInt(row['updated_at']) ?? 0,
    trackCount: _asInt(row['track_count']) ?? 0,
    durationMillis: _asInt(row['duration_ms']) ?? 0,
    isSmart: _asInt(row['is_smart']) == 1,
    smartRule: _asInt(row['is_smart']) == 1
        ? SmartPlaylistRule.decode(row['smart_rules_json'] as String?)
        : null,
  );

  static int? _asInt(Object? value) => switch (value) {
    int v => v,
    num v => v.toInt(),
    _ => null,
  };
}
