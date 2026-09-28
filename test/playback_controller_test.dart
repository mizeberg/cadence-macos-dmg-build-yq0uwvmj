import 'dart:async';

import 'package:cadence_music/core/database/app_database.dart';
import 'package:cadence_music/core/database/database_provider.dart';
import 'package:cadence_music/features/library/data/local_library_repository.dart';
import 'package:cadence_music/features/library/domain/song.dart';
import 'package:cadence_music/features/playback/application/playback_controller.dart';
import 'package:cadence_music/features/playback/data/audio_engine.dart';
import 'package:cadence_music/features/playback/data/audio_output_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'playback controller opens local songs and synchronizes queue controls',
    () async {
      final database = await AppDatabase.open(inMemory: true);
      final engine = _FakeAudioEngine();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          audioEngineProvider.overrideWithValue(engine),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await engine.dispose();
        await database.close();
      });

      final songs = [
        _song('/music/first.wav', 'First'),
        _song('/music/second.flac', 'Second'),
      ];
      await LocalLibraryRepository(database.connection).upsertSongs(songs);
      final controller = container.read(playbackControllerProvider.notifier);

      await controller.playQueue(songs);
      await _flush();
      expect(
        container.read(playbackControllerProvider).currentSong?.title,
        'First',
      );
      expect(container.read(playbackControllerProvider).isPlaying, isTrue);
      expect(engine.openedPaths, ['/music/first.wav']);

      await controller.next();
      await _flush();
      expect(
        container.read(playbackControllerProvider).currentSong?.title,
        'Second',
      );
      expect(engine.openedPaths.last, '/music/second.flac');

      await controller.seek(const Duration(seconds: 42));
      expect(engine.lastPosition, const Duration(seconds: 42));
      await controller.setVolume(.35);
      expect(engine.lastVolume, .35);
      expect(container.read(playbackControllerProvider).volume, .35);

      await controller.togglePlayPause();
      await _flush();
      expect(container.read(playbackControllerProvider).isPlaying, isFalse);

      await controller.previous();
      await _flush();
      expect(
        container.read(playbackControllerProvider).currentSong?.title,
        'Second',
      );
      expect(engine.lastPosition, Duration.zero);

      await controller.previous();
      await _flush();
      expect(
        container.read(playbackControllerProvider).currentSong?.title,
        'First',
      );
      expect(engine.lastOpenPlayed, isFalse);

      controller.clearQueue();
      await _flush();
      expect(container.read(playbackControllerProvider).currentSong, isNull);
      expect(container.read(playbackControllerProvider).queue.isEmpty, isTrue);
    },
  );

  test(
    'online tracks stream through the queue without local play history',
    () async {
      final database = await AppDatabase.open(inMemory: true);
      final engine = _FakeAudioEngine();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          audioEngineProvider.overrideWithValue(engine),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await engine.dispose();
        await database.close();
      });

      final onlineTrack = Song(
        id: 'jamendo:123',
        path: 'https://audio.example.test/track.mp3',
        title: 'Online track',
        artist: 'Test artist',
        modifiedAtMillis: 0,
        fileSizeBytes: 0,
        addedAtMillis: 0,
        sourceName: 'Jamendo',
        sourceUrl: 'https://www.jamendo.com/track/123',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      );

      await container.read(playbackControllerProvider.notifier).playQueue([
        onlineTrack,
      ]);
      await _flush();

      expect(engine.openedPaths, [onlineTrack.path]);
      final rows = await database.connection.rawQuery(
        'SELECT COUNT(*) AS count FROM play_history',
      );
      expect(rows.single['count'], 0);
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

Song _song(String path, String title) => Song(
  id: path,
  path: path,
  title: title,
  artist: 'Test artist',
  modifiedAtMillis: 1,
  fileSizeBytes: 10,
  addedAtMillis: 1,
);

class _FakeAudioEngine implements AudioEngine {
  static const _defaultDevice = AudioOutputDevice(
    id: 'auto',
    name: 'auto',
    description: '',
    isAutomatic: true,
  );
  final StreamController<Duration> _position = StreamController.broadcast();
  final StreamController<Duration> _duration = StreamController.broadcast();
  final StreamController<bool> _playing = StreamController.broadcast();
  final StreamController<bool> _completed = StreamController.broadcast();
  final StreamController<double> _volume = StreamController.broadcast();
  final StreamController<String> _error = StreamController.broadcast();
  final List<String> openedPaths = [];
  Duration lastPosition = Duration.zero;
  double lastVolume = 1;
  bool lastOpenPlayed = false;

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration> get durationStream => _duration.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get completedStream => _completed.stream;
  @override
  Stream<double> get volumeStream => _volume.stream;
  @override
  Stream<String> get errorStream => _error.stream;
  @override
  Stream<List<AudioOutputDevice>> get outputDevicesStream =>
      Stream.value(const [_defaultDevice]);
  @override
  Stream<AudioOutputDevice> get outputDeviceStream =>
      Stream.value(_defaultDevice);
  @override
  Stream<DecodedAudioFormat?> get decodedFormatStream => Stream.value(null);
  @override
  Stream<bool> get bufferingStream => Stream.value(false);
  @override
  Stream<Duration> get bufferPositionStream => Stream.value(Duration.zero);

  @override
  Future<void> open(String path, {required bool play}) async {
    openedPaths.add(path);
    lastOpenPlayed = play;
    _duration.add(const Duration(minutes: 3));
    _position.add(Duration.zero);
    _playing.add(play);
  }

  @override
  Future<void> play() async => _playing.add(true);
  @override
  Future<void> pause() async => _playing.add(false);
  @override
  Future<void> stop() async => _playing.add(false);
  @override
  Future<void> seek(Duration position) async {
    lastPosition = position;
    _position.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
    _volume.add(volume);
  }

  @override
  Future<void> selectOutputDevice(String id) async {}

  @override
  Future<void> dispose() async {
    await Future.wait([
      _position.close(),
      _duration.close(),
      _playing.close(),
      _completed.close(),
      _volume.close(),
      _error.close(),
    ]);
  }
}
