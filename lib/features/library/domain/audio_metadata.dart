import 'dart:typed_data';

class AudioMetadata {
  const AudioMetadata({
    this.title,
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
    this.lossless,
    this.bitrate,
    this.bitrateMode,
    this.bpm,
    this.replayGainTrackGain,
    this.replayGainTrackPeak,
    this.replayGainAlbumGain,
    this.replayGainAlbumPeak,
    this.fileSizeBytes,
    this.artworkBytes,
    this.artworkMimeType,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final String? lyrics;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMillis;
  final String? codec;
  final String? containerFormat;
  final int? sampleRate;
  final int? bitsPerSample;
  final int? channels;
  final bool? lossless;
  final int? bitrate;
  final String? bitrateMode;
  final double? bpm;
  final double? replayGainTrackGain;
  final double? replayGainTrackPeak;
  final double? replayGainAlbumGain;
  final double? replayGainAlbumPeak;
  final int? fileSizeBytes;
  final Uint8List? artworkBytes;
  final String? artworkMimeType;
}

abstract interface class AudioMetadataReader {
  Future<AudioMetadata> read(String path);
}
