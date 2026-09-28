import '../../library/domain/song.dart';

/// One Jamendo catalog result. Audio is streamed from the provider URL and is
/// never downloaded or added to Cadence's local-file database.
class JamendoTrack {
  const JamendoTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.contentUrl,
    required this.durationSeconds,
    this.album,
    this.artworkUrl,
    this.licenseUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String contentUrl;
  final int durationSeconds;
  final String? album;
  final String? artworkUrl;
  final String? licenseUrl;

  String get licenseLabel {
    final path = Uri.tryParse(licenseUrl ?? '')?.path ?? '';
    final match = RegExp(r'/licenses/([^/]+)/([^/]+)/?').firstMatch(path);
    if (match == null) return 'License details';
    final code = match.group(1)!.toUpperCase();
    final version = match.group(2);
    return 'CC $code $version';
  }

  Song toSong() => Song(
    id: 'jamendo:$id',
    path: audioUrl,
    title: title,
    artist: artist,
    album: album,
    durationMillis: durationSeconds > 0 ? durationSeconds * 1000 : null,
    modifiedAtMillis: 0,
    fileSizeBytes: 0,
    addedAtMillis: 0,
    artworkPath: artworkUrl,
    sourceName: 'Jamendo',
    sourceUrl: contentUrl,
    licenseUrl: licenseUrl,
    licenseLabel: licenseLabel,
  );

  factory JamendoTrack.fromJson(Map<String, Object?> json) {
    final id = _string(json['id']);
    final title = _string(json['name']);
    final artist = _string(json['artist_name']);
    // Stream playback must never silently downgrade to cleartext HTTP.
    final audio = _httpsUrl(json['audio']);
    if (id == null || title == null || artist == null || audio == null) {
      throw const FormatException('Jamendo returned an incomplete track.');
    }

    final content =
        _httpsUrl(json['shareurl'], upgradeHttp: true) ??
        'https://www.jamendo.com/track/$id';
    return JamendoTrack(
      id: id,
      title: title,
      artist: artist,
      audioUrl: audio,
      contentUrl: content,
      durationSeconds: _integer(json['duration']) ?? 0,
      album: _string(json['album_name']),
      artworkUrl:
          _httpsUrl(json['image'], upgradeHttp: true) ??
          _httpsUrl(json['album_image'], upgradeHttp: true),
      licenseUrl: _licenseUrl(json),
    );
  }

  static String? _licenseUrl(Map<String, Object?> json) {
    for (final key in const ['license_ccurl', 'license_cc_url']) {
      final value = _creativeCommonsUrl(json[key]);
      if (value != null) return value;
    }
    return _findCreativeCommonsUrl(json['licenses']);
  }

  static String? _findCreativeCommonsUrl(Object? value) {
    if (value is String) return _creativeCommonsUrl(value);
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key.toString().toLowerCase().contains('cc')) {
          final direct = _creativeCommonsUrl(entry.value);
          if (direct != null) return direct;
        }
      }
      for (final nested in value.values) {
        final found = _findCreativeCommonsUrl(nested);
        if (found != null) return found;
      }
    }
    if (value is Iterable) {
      for (final nested in value) {
        final found = _findCreativeCommonsUrl(nested);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String? _creativeCommonsUrl(Object? value) {
    final url = _httpsUrl(value, upgradeHttp: true);
    if (url == null) return null;
    final host = Uri.parse(url).host.toLowerCase();
    return host == 'creativecommons.org' ||
            host.endsWith('.creativecommons.org')
        ? url
        : null;
  }

  static String? _httpsUrl(Object? value, {bool upgradeHttp = false}) {
    final text = _string(value);
    if (text == null) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme == 'https') return uri.toString();
    if (upgradeHttp && uri.scheme == 'http') {
      return uri.replace(scheme: 'https').toString();
    }
    return null;
  }

  static String? _string(Object? value) {
    if (value is! String && value is! num) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  static int? _integer(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };
}
