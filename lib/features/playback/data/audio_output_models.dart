class AudioOutputDevice {
  const AudioOutputDevice({
    required this.id,
    required this.name,
    required this.description,
    required this.isAutomatic,
  });

  final String id;
  final String name;
  final String description;
  final bool isAutomatic;

  String get displayName => isAutomatic
      ? 'Automatic (system default)'
      : description.isNotEmpty
      ? description
      : name;

  bool get appearsBluetooth =>
      '$name $description'.toLowerCase().contains('bluetooth') ||
      '$name $description'.toLowerCase().contains('airpods');
}

class DecodedAudioFormat {
  const DecodedAudioFormat({
    this.sampleFormat,
    this.sampleRate,
    this.channelLayout,
    this.channelCount,
    this.bitrateKbps,
  });

  /// Decoder-reported PCM format; it does not prove the hardware DAC format.
  final String? sampleFormat;
  final int? sampleRate;
  final String? channelLayout;
  final int? channelCount;
  final double? bitrateKbps;

  bool get isEmpty =>
      sampleFormat == null &&
      sampleRate == null &&
      channelLayout == null &&
      channelCount == null &&
      bitrateKbps == null;
}
