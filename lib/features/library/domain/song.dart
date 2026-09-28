/// Indexed metadata for one user-owned local audio file.
class Song {
  const Song({
    required this.id,
    required this.path,
    required this.title,
    required this.modifiedAtMillis,
    required this.fileSizeBytes,
    required this.addedAtMillis,
    this.libraryRootId,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.lyrics,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.durationMillis,
    this.codec,
    this.containerFormat,
    this.sampleRate,
    this.bitsPerSample,
    this.channels,
    this.isLossless = false,
    this.bitrate,
    this.bitrateMode,
    this.bpm,
    this.replayGainTrackGain,
    this.replayGainTrackPeak,
    this.replayGainAlbumGain,
    this.replayGainAlbumPeak,
    this.artworkPath,
    this.lastPlayedAtMillis,
    this.playCount = 0,
    this.skipCount = 0,
    this.completionPercent,
    this.rating = 0,
    this.isFavorite = false,
    this.sourceName,
    this.sourceUrl,
    this.licenseUrl,
    this.licenseLabel,
  });

  /// Stable database ID. The canonical absolute file path is used as the ID.
  final String id;
  final String path;
  final String title;
  final String? libraryRootId;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final String? lyrics;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMillis;
  final int modifiedAtMillis;
  final int fileSizeBytes;

  /// Detected from audio properties, not inferred from the file name.
  final String? codec;
  final String? containerFormat;
  final int? sampleRate;
  final int? bitsPerSample;
  final int? channels;
  final bool isLossless;
  final int? bitrate;
  final String? bitrateMode;
  final double? bpm;
  final double? replayGainTrackGain;
  final double? replayGainTrackPeak;
  final double? replayGainAlbumGain;
  final double? replayGainAlbumPeak;

  final String? artworkPath;
  final int addedAtMillis;
  final int? lastPlayedAtMillis;
  final int playCount;
  final int skipCount;
  final double? completionPercent;
  final int rating;
  final bool isFavorite;

  /// Present only for provider results; online tracks are not local DB rows.
  final String? sourceName;
  final String? sourceUrl;
  final String? licenseUrl;
  final String? licenseLabel;

  bool get isOnline => sourceName != null;

  String get displayArtist =>
      _clean(artist) ?? _clean(albumArtist) ?? 'Unknown artist';
  String get displayAlbum => _clean(album) ?? 'Unknown album';
  Duration get duration => Duration(milliseconds: durationMillis ?? 0);
  String get displayCodec => _clean(codec) ?? 'Unknown';
  String get displayContainer => _clean(containerFormat) ?? displayCodec;

  /// Conservative display threshold: verified lossless source, >=24 bit and
  /// >=88.2 kHz. Unknown properties never earn a quality badge.
  bool get isHiResLossless =>
      isLossless && (bitsPerSample ?? 0) >= 24 && (sampleRate ?? 0) >= 88200;

  Map<String, Object?> toDatabaseMap() => {
    'id': id,
    'path': path,
    'library_root_id': libraryRootId,
    'title': title,
    'artist': artist,
    'album': album,
    'album_artist': albumArtist,
    'genre': genre,
    'lyrics': lyrics,
    'year': year,
    'track_number': trackNumber,
    'disc_number': discNumber,
    'duration_ms': durationMillis,
    'modified_at': modifiedAtMillis,
    'file_size': fileSizeBytes,
    'codec': codec,
    'container_format': containerFormat,
    'sample_rate': sampleRate,
    'bits_per_sample': bitsPerSample,
    'channels': channels,
    'is_lossless': isLossless ? 1 : 0,
    'bitrate': bitrate,
    'bitrate_mode': bitrateMode,
    'bpm': bpm,
    'replaygain_track_gain': replayGainTrackGain,
    'replaygain_track_peak': replayGainTrackPeak,
    'replaygain_album_gain': replayGainAlbumGain,
    'replaygain_album_peak': replayGainAlbumPeak,
    'artwork_path': artworkPath,
    'added_at': addedAtMillis,
    'last_played_at': lastPlayedAtMillis,
    'play_count': playCount,
    'skip_count': skipCount,
    'completion_percent': completionPercent,
    'rating': rating,
    'is_favorite': isFavorite ? 1 : 0,
  };

  factory Song.fromDatabaseMap(Map<String, Object?> row) => Song(
    id: row['id']! as String,
    path: row['path']! as String,
    libraryRootId: row['library_root_id'] as String?,
    title: row['title']! as String,
    artist: row['artist'] as String?,
    album: row['album'] as String?,
    albumArtist: row['album_artist'] as String?,
    genre: row['genre'] as String?,
    lyrics: row['lyrics'] as String?,
    year: _asInt(row['year']),
    trackNumber: _asInt(row['track_number']),
    discNumber: _asInt(row['disc_number']),
    durationMillis: _asInt(row['duration_ms']),
    modifiedAtMillis: _asInt(row['modified_at']) ?? 0,
    fileSizeBytes: _asInt(row['file_size']) ?? 0,
    codec: row['codec'] as String?,
    containerFormat: row['container_format'] as String?,
    sampleRate: _asInt(row['sample_rate']),
    bitsPerSample: _asInt(row['bits_per_sample']),
    channels: _asInt(row['channels']),
    isLossless: _asInt(row['is_lossless']) == 1,
    bitrate: _asInt(row['bitrate']),
    bitrateMode: row['bitrate_mode'] as String?,
    bpm: _asDouble(row['bpm']),
    replayGainTrackGain: _asDouble(row['replaygain_track_gain']),
    replayGainTrackPeak: _asDouble(row['replaygain_track_peak']),
    replayGainAlbumGain: _asDouble(row['replaygain_album_gain']),
    replayGainAlbumPeak: _asDouble(row['replaygain_album_peak']),
    artworkPath: row['artwork_path'] as String?,
    addedAtMillis: _asInt(row['added_at']) ?? 0,
    lastPlayedAtMillis: _asInt(row['last_played_at']),
    playCount: _asInt(row['play_count']) ?? 0,
    skipCount: _asInt(row['skip_count']) ?? 0,
    completionPercent: _asDouble(row['completion_percent']),
    rating: _asInt(row['rating']) ?? 0,
    isFavorite: _asInt(row['is_favorite']) == 1,
  );

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    String? lyrics,
    int? durationMillis,
    String? artworkPath,
    int? lastPlayedAtMillis,
    int? playCount,
    int? skipCount,
    double? completionPercent,
    int? rating,
    bool? isFavorite,
  }) => Song(
    id: id,
    path: path,
    title: title ?? this.title,
    libraryRootId: libraryRootId,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    albumArtist: albumArtist ?? this.albumArtist,
    genre: genre ?? this.genre,
    lyrics: lyrics ?? this.lyrics,
    year: year,
    trackNumber: trackNumber,
    discNumber: discNumber,
    durationMillis: durationMillis ?? this.durationMillis,
    modifiedAtMillis: modifiedAtMillis,
    fileSizeBytes: fileSizeBytes,
    codec: codec,
    containerFormat: containerFormat,
    sampleRate: sampleRate,
    bitsPerSample: bitsPerSample,
    channels: channels,
    isLossless: isLossless,
    bitrate: bitrate,
    bitrateMode: bitrateMode,
    bpm: bpm,
    replayGainTrackGain: replayGainTrackGain,
    replayGainTrackPeak: replayGainTrackPeak,
    replayGainAlbumGain: replayGainAlbumGain,
    replayGainAlbumPeak: replayGainAlbumPeak,
    artworkPath: artworkPath ?? this.artworkPath,
    addedAtMillis: addedAtMillis,
    lastPlayedAtMillis: lastPlayedAtMillis ?? this.lastPlayedAtMillis,
    playCount: playCount ?? this.playCount,
    skipCount: skipCount ?? this.skipCount,
    completionPercent: completionPercent ?? this.completionPercent,
    rating: rating ?? this.rating,
    isFavorite: isFavorite ?? this.isFavorite,
    sourceName: sourceName,
    sourceUrl: sourceUrl,
    licenseUrl: licenseUrl,
    licenseLabel: licenseLabel,
  );

  static int? _asInt(Object? value) => switch (value) {
    int v => v,
    num v => v.toInt(),
    _ => null,
  };

  static double? _asDouble(Object? value) => switch (value) {
    double v => v,
    num v => v.toDouble(),
    _ => null,
  };

  static String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
