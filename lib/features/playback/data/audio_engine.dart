import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_kit_audio_engine.dart';
import 'audio_output_models.dart';

abstract interface class AudioEngine {
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;
  Stream<double> get volumeStream;
  Stream<String> get errorStream;
  Stream<List<AudioOutputDevice>> get outputDevicesStream;
  Stream<AudioOutputDevice> get outputDeviceStream;
  Stream<DecodedAudioFormat?> get decodedFormatStream;
  Stream<bool> get bufferingStream;
  Stream<Duration> get bufferPositionStream;

  Future<void> open(String path, {required bool play});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> selectOutputDevice(String id);
  Future<void> dispose();
}

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = MediaKitAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
