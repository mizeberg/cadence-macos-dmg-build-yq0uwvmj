import 'package:media_kit/media_kit.dart';

import 'audio_engine.dart';
import 'audio_output_models.dart';

class MediaKitAudioEngine implements AudioEngine {
  MediaKitAudioEngine({Player? player}) : _player = player ?? Player();

  final Player _player;

  @override
  Stream<Duration> get positionStream => _player.stream.position;
  @override
  Stream<Duration> get durationStream => _player.stream.duration;
  @override
  Stream<bool> get playingStream => _player.stream.playing;
  @override
  Stream<bool> get completedStream => _player.stream.completed;
  @override
  Stream<double> get volumeStream =>
      _player.stream.volume.map((value) => value / 100);
  @override
  Stream<String> get errorStream => _player.stream.error;
  @override
  Stream<List<AudioOutputDevice>> get outputDevicesStream async* {
    yield _player.state.audioDevices.map(_mapDevice).toList(growable: false);
    yield* _player.stream.audioDevices.map(
      (devices) => devices.map(_mapDevice).toList(growable: false),
    );
  }

  @override
  Stream<AudioOutputDevice> get outputDeviceStream async* {
    yield _mapDevice(_player.state.audioDevice);
    yield* _player.stream.audioDevice.map(_mapDevice);
  }

  @override
  Stream<DecodedAudioFormat?> get decodedFormatStream async* {
    yield _mapAudioParams(_player.state.audioParams);
    yield* _player.stream.audioParams.map(_mapAudioParams);
  }

  @override
  Stream<bool> get bufferingStream async* {
    yield _player.state.buffering;
    yield* _player.stream.buffering;
  }

  @override
  Stream<Duration> get bufferPositionStream async* {
    yield _player.state.buffer;
    yield* _player.stream.buffer;
  }

  @override
  Future<void> open(String path, {required bool play}) =>
      _player.open(Media(path), play: play);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume((volume.clamp(0, 1) * 100).toDouble());

  @override
  Future<void> selectOutputDevice(String id) async {
    final device = _player.state.audioDevices.cast<AudioDevice?>().firstWhere(
      (candidate) => candidate?.name == id,
      orElse: AudioDevice.auto,
    );
    await _player.setAudioDevice(device!);
  }

  @override
  Future<void> dispose() => _player.dispose();

  static AudioOutputDevice _mapDevice(AudioDevice device) =>
      AudioOutputDevice(
        id: device.name,
        name: device.name,
        description: device.description,
        isAutomatic: device.name == 'auto',
      );

  static DecodedAudioFormat? _mapAudioParams(AudioParams params) {
    final mapped = DecodedAudioFormat(
      sampleFormat: params.format,
      sampleRate: params.sampleRate,
      channelLayout: params.hrChannels ?? params.channels,
      channelCount: params.channelCount,
    );
    return mapped.isEmpty ? null : mapped;
  }
}
