import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../playback/application/audio_engine_providers.dart';
import '../domain/song.dart';

Future<void> showAudioInfoDialog(BuildContext context, Song song) =>
    showDialog<void>(
      context: context,
      builder: (context) => _AudioInfoDialog(song: song),
    );

class _AudioInfoDialog extends ConsumerWidget {
  const _AudioInfoDialog({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selected = ref.watch(selectedAudioOutputProvider).valueOrNull;
    final decoded = ref.watch(decodedAudioFormatProvider).valueOrNull;
    final buffering = ref.watch(audioBufferingProvider).valueOrNull;
    final bufferPosition = ref.watch(audioBufferPositionProvider).valueOrNull;
    final diagnostic = _diagnostics(
      song,
      selected?.displayName,
      decoded?.sampleFormat,
      decoded?.sampleRate,
      decoded?.channelLayout,
      buffering,
    );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio information',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _InfoCard(
                        title: 'Source file format',
                        children: [
                          _InfoRow('Codec', song.displayCodec),
                          _InfoRow('Container', song.displayContainer),
                          _InfoRow(
                            'Quality',
                            song.isHiResLossless
                                ? 'Hi-Res lossless (source verified)'
                                : song.isLossless
                                ? 'Lossless (source verified)'
                                : song.codec == null
                                ? 'Unknown — no format data'
                                : 'Lossy or source format not classified as lossless',
                          ),
                          _InfoRow(
                            'Bit depth',
                            song.bitsPerSample == null
                                ? 'Unknown'
                                : '${song.bitsPerSample}-bit',
                          ),
                          _InfoRow('Sample rate', _sampleRate(song.sampleRate)),
                          _InfoRow('Channels', _channels(song.channels)),
                          _InfoRow(
                            'Bitrate',
                            song.bitrate == null
                                ? 'Unknown'
                                : '${song.bitrate} kb/s${song.bitrateMode == 'vbr'
                                      ? ' · variable'
                                      : song.bitrateMode == 'cbr'
                                      ? ' · constant'
                                      : ''}',
                          ),
                          _InfoRow('Duration', _duration(song.duration)),
                          _InfoRow('File size', _fileSize(song.fileSizeBytes)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Playback path',
                        children: [
                          _InfoRow(
                            'Decoder',
                            'media_kit / libmpv audio backend',
                          ),
                          _InfoRow(
                            'Output device',
                            selected?.displayName ?? 'Waiting for device information',
                          ),
                          _InfoRow(
                            'Decoder PCM',
                            decoded == null
                                ? 'Unavailable until playback starts'
                                : '${decoded.sampleFormat ?? 'Unknown format'} · ${_sampleRate(decoded.sampleRate)} · ${decoded.channelLayout ?? _channels(decoded.channelCount)}',
                          ),
                          _InfoRow(
                            'Decoder buffering',
                            buffering == null
                                ? 'Unavailable'
                                : '${buffering ? 'Buffering' : 'Not buffering'}${bufferPosition == null ? '' : ' · ${bufferPosition.inSeconds}s demux buffer'}',
                          ),
                          _InfoRow(
                            'DSP',
                            'No app EQ, ReplayGain, normalization, or crossfade is applied',
                          ),
                          _InfoRow(
                            'Direct / bit-perfect',
                            'Not exposed or verifiable; no bit-perfect claim',
                          ),
                          if (selected?.appearsBluetooth ?? false)
                            const _InfoRow(
                              'Bluetooth note',
                              'System/codec processing may alter the signal; bit-perfect output is not claimed.',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Embedded tags',
                        children: [
                          _InfoRow('Album', song.displayAlbum),
                          _InfoRow('Artist', song.displayArtist),
                          _InfoRow('Genre', song.genre ?? 'Not set'),
                          _InfoRow(
                            'Rating',
                            song.rating == 0
                                ? 'Not rated'
                                : '${song.rating} / 5',
                          ),
                          _InfoRow(
                            'ReplayGain track',
                            _gain(song.replayGainTrackGain),
                          ),
                          _InfoRow(
                            'ReplayGain album',
                            _gain(song.replayGainAlbumGain),
                          ),
                          _InfoRow(
                            'Embedded artwork',
                            song.artworkPath == null
                                ? 'Not found'
                                : 'Cached locally',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Lossless and Hi-Res badges describe the detected source file only. Cadence cannot confirm the hardware output format or guarantee bit-perfect delivery through the system mixer.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: diagnostic));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Audio diagnostics copied.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('Copy diagnostics'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _sampleRate(int? value) => value == null
      ? 'Unknown'
      : value >= 1000
      ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)} kHz'
      : '$value Hz';

  static String _channels(int? value) => switch (value) {
    1 => 'Mono (1 channel)',
    2 => 'Stereo (2 channels)',
    null => 'Unknown',
    _ => '$value channels',
  };

  static String _duration(Duration duration) {
    if (duration <= Duration.zero) return 'Unknown';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$minutes:$seconds'
        : '${duration.inMinutes}:$seconds';
  }

  static String _fileSize(int bytes) {
    if (bytes <= 0) return 'Unknown';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _gain(double? value) =>
      value == null ? 'Not tagged' : '${value.toStringAsFixed(2)} dB';

  static String _diagnostics(
    Song song,
    String? outputDevice,
    String? decodedFormat,
    int? decodedSampleRate,
    String? decodedChannels,
    bool? buffering,
  ) => [
    'Cadence audio diagnostics',
    'Track: ${song.title}',
    'Path: ${song.path}',
    'Source codec: ${song.codec ?? 'unknown'}',
    'Container: ${song.containerFormat ?? 'unknown'}',
    'Source lossless: ${song.isLossless}',
    'Sample rate: ${song.sampleRate ?? 'unknown'} Hz',
    'Bit depth: ${song.bitsPerSample ?? 'unknown'}',
    'Channels: ${song.channels ?? 'unknown'}',
    'Bitrate: ${song.bitrate ?? 'unknown'} kb/s',
    'Playback backend: media_kit / libmpv',
    'Selected output device: ${outputDevice ?? 'not available'}',
    'Decoder PCM format: ${decodedFormat ?? 'not available'}',
    'Decoder PCM sample rate: ${decodedSampleRate ?? 'not available'} Hz',
    'Decoder PCM channels: ${decodedChannels ?? 'not available'}',
    'Buffering: ${buffering == null ? 'not available' : buffering ? 'yes' : 'no'}',
    'DAC/output format: not exposed; system-managed downstream',
    'Bit-perfect: not claimed or verifiable',
    'Application DSP: none applied',
  ].join('\n');
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 165,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
