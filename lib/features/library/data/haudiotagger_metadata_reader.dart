import 'package:haudiotagger/haudiotagger.dart';

import '../domain/audio_metadata.dart';

class HaudiotaggerMetadataReader implements AudioMetadataReader {
  const HaudiotaggerMetadataReader({this.maxArtworkBytes = 12 * 1024 * 1024});

  final int maxArtworkBytes;

  @override
  Future<AudioMetadata> read(String path) async {
    final tags = await Haudiotagger.read(path);
    final properties = await Haudiotagger.readProperties(path);
    final artwork = _chooseArtwork(tags?.pictures ?? const []);
    final durationMicros = properties.durationMicros;

    return AudioMetadata(
      title: _clean(tags?.title),
      artist: _clean(tags?.trackArtist),
      album: _clean(tags?.album),
      albumArtist: _clean(tags?.albumArtist),
      genre: _clean(tags?.genre),
      lyrics: _clean(tags?.lyrics),
      year: tags?.year,
      trackNumber: tags?.trackNumber,
      discNumber: tags?.discNumber,
      durationMillis: durationMicros == null
          ? null
          : (durationMicros / 1000).round(),
      codec: _clean(properties.codec),
      containerFormat: _clean(properties.containerFormat),
      sampleRate: properties.sampleRate,
      bitsPerSample: properties.bitsPerSample,
      channels: properties.channels,
      lossless: properties.lossless,
      bitrate: properties.bitrate,
      bitrateMode: properties.bitrateMode.name,
      bpm: tags?.bpm,
      replayGainTrackGain: _number(tags?.replayGainTrackGain),
      replayGainTrackPeak: _number(tags?.replayGainTrackPeak),
      replayGainAlbumGain: _number(tags?.replayGainAlbumGain),
      replayGainAlbumPeak: _number(tags?.replayGainAlbumPeak),
      fileSizeBytes: properties.fileSize?.toInt(),
      artworkBytes: artwork?.bytes,
      artworkMimeType: _mime(artwork?.mimeType),
    );
  }

  Picture? _chooseArtwork(List<Picture> pictures) {
    if (pictures.isEmpty) return null;
    final candidates = [
      ...pictures.where((p) => p.pictureType == PictureType.coverFront),
      ...pictures.where((p) => p.pictureType != PictureType.coverFront),
    ];
    for (final picture in candidates) {
      if (picture.bytes.isNotEmpty && picture.bytes.length <= maxArtworkBytes) {
        return picture;
      }
    }
    return null;
  }

  static String? _mime(MimeType? value) => switch (value) {
    MimeType.png => 'image/png',
    MimeType.jpeg => 'image/jpeg',
    MimeType.tiff => 'image/tiff',
    MimeType.bmp => 'image/bmp',
    MimeType.gif => 'image/gif',
    null => null,
  };

  static String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  static double? _number(String? value) =>
      double.tryParse(value?.trim() ?? '');
}
