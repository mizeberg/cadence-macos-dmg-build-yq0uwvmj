import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repository_providers.dart';
import '../../library/application/library_search_providers.dart';
import '../data/audio_engine.dart';
import '../data/audio_output_models.dart';
import '../domain/playback_queue.dart';
import '../../library/domain/song.dart';

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);

const _automaticAudioDevice = AudioOutputDevice(
  id: 'auto',
  name: 'auto',
  description: '',
  isAutomatic: true,
);

class PlaybackState {
  PlaybackState({
    PlaybackQueue? queue,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1,
    this.error,
    this.selectedAudioOutput = _automaticAudioDevice,
    this.audioDeviceNotice,
  }) : queue = queue ?? PlaybackQueue.empty();

  final PlaybackQueue queue;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final double volume;
  final String? error;
  final AudioOutputDevice selectedAudioOutput;
  final String? audioDeviceNotice;

  Song? get currentSong => queue.currentSong;

  PlaybackState copyWith({
    PlaybackQueue? queue,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    double? volume,
    String? error,
    bool clearError = false,
    AudioOutputDevice? selectedAudioOutput,
    String? audioDeviceNotice,
    bool clearAudioDeviceNotice = false,
  }) => PlaybackState(
    queue: queue ?? this.queue,
    isPlaying: isPlaying ?? this.isPlaying,
    isLoading: isLoading ?? this.isLoading,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    volume: volume ?? this.volume,
    error: clearError ? null : error ?? this.error,
    selectedAudioOutput: selectedAudioOutput ?? this.selectedAudioOutput,
    audioDeviceNotice: clearAudioDeviceNotice
        ? null
        : audioDeviceNotice ?? this.audioDeviceNotice,
  );
}

class PlaybackController extends Notifier<PlaybackState> {
  late AudioEngine _engine;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _disposed = false;
  int? _activeHistoryId;
  String? _activeHistorySongId;
  int _sessionMaxPositionMillis = 0;
  bool _outputDeviceSnapshotLoaded = false;
  Set<String> _availableOutputDeviceIds = {};
  String? _disconnectedOutputDeviceId;

  @override
  PlaybackState build() {
    _engine = ref.watch(audioEngineProvider);
    _subscriptions.add(
      _engine.positionStream.listen((position) {
        if (_disposed) return;
        _sessionMaxPositionMillis = max(
          _sessionMaxPositionMillis,
          position.inMilliseconds,
        );
        final duration = state.duration;
        state = state.copyWith(
          position: duration > Duration.zero && position > duration
              ? duration
              : position,
        );
      }),
    );
    _subscriptions.add(
      _engine.durationStream.listen((duration) {
        if (!_disposed) state = state.copyWith(duration: duration);
      }),
    );
    _subscriptions.add(
      _engine.playingStream.listen((playing) {
        if (!_disposed) {
          state = state.copyWith(isPlaying: playing, isLoading: false);
        }
      }),
    );
    _subscriptions.add(
      _engine.volumeStream.listen((volume) {
        if (!_disposed) {
          state = state.copyWith(volume: volume.clamp(0, 1).toDouble());
        }
      }),
    );
    _subscriptions.add(
      _engine.completedStream.listen((completed) {
        if (completed && !_disposed) unawaited(next());
      }),
    );
    _subscriptions.add(
      _engine.errorStream.listen((message) {
        if (!_disposed) {
          _reportError(StateError(message), StackTrace.current);
        }
      }),
    );
    _subscriptions.add(
      _engine.outputDeviceStream.listen((device) {
        if (!_disposed) {
          state = state.copyWith(selectedAudioOutput: device);
        }
      }),
    );
    _subscriptions.add(
      _engine.outputDevicesStream.listen((devices) {
        if (!_disposed) unawaited(_handleOutputDevices(devices));
      }),
    );
    ref.onDispose(() {
      _disposed = true;
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
    });
    return PlaybackState();
  }

  Future<void> playSong(Song song) => playQueue([song]);

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    await _finishSession(interrupted: true);
    final queue = PlaybackQueue.empty().playAll(songs, startIndex: startIndex);
    state = state.copyWith(
      queue: queue,
      position: Duration.zero,
      duration: Duration.zero,
      isLoading: true,
      clearError: true,
    );
    await _openCurrent(play: true);
  }

  Future<void> togglePlayPause() async {
    if (state.currentSong == null) return;
    try {
      if (state.isPlaying) {
        await _engine.pause();
      } else if (state.position > Duration.zero &&
          state.duration > Duration.zero) {
        await _engine.play();
      } else {
        state = state.copyWith(isLoading: true, clearError: true);
        await _openCurrent(play: true);
      }
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<void> next() async {
    final nextQueue = state.queue.next();
    if (nextQueue == null) {
      await _finishSession(interrupted: false);
      state = state.copyWith(isPlaying: false, isLoading: false);
      return;
    }
    await _finishSession(interrupted: true);
    state = state.copyWith(
      queue: nextQueue,
      position: Duration.zero,
      duration: Duration.zero,
      isLoading: true,
      clearError: true,
    );
    await _openCurrent(play: true);
  }

  Future<void> previous() async {
    if (state.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    final previousQueue = state.queue.previous();
    if (previousQueue == null) return;
    await _finishSession(interrupted: true);
    final wasPlaying = state.isPlaying;
    state = state.copyWith(
      queue: previousQueue,
      position: Duration.zero,
      duration: Duration.zero,
      isLoading: true,
      clearError: true,
    );
    await _openCurrent(play: wasPlaying);
  }

  void addToQueue(Song song) {
    state = state.copyWith(queue: state.queue.addAll([song]));
  }

  void playNext(Song song) {
    state = state.copyWith(queue: state.queue.insertNext(song));
  }

  Future<void> removeQueueAt(int index) async {
    final previousId = state.currentSong?.id;
    final wasPlaying = state.isPlaying;
    final queue = state.queue.removeAt(index);
    if (queue.currentSong?.id != previousId) {
      await _finishSession(interrupted: true);
    }
    state = state.copyWith(queue: queue);
    if (queue.currentSong?.id != previousId) {
      if (queue.currentSong == null) {
        try {
          await _engine.stop();
          state = state.copyWith(
            isPlaying: false,
            isLoading: false,
            position: Duration.zero,
            duration: Duration.zero,
          );
        } catch (error, stackTrace) {
          _reportError(error, stackTrace);
        }
      } else {
        state = state.copyWith(
          isLoading: true,
          position: Duration.zero,
          duration: Duration.zero,
        );
        await _openCurrent(play: wasPlaying);
      }
    }
  }

  void moveQueue(int oldIndex, int newIndex) {
    state = state.copyWith(queue: state.queue.move(oldIndex, newIndex));
  }

  Future<void> clearQueue() async {
    try {
      await _finishSession(interrupted: true);
      await _engine.stop();
      state = PlaybackState(volume: state.volume);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void toggleShuffle() {
    state = state.copyWith(
      queue: state.queue.toggleShuffle(random: Random.secure()),
    );
  }

  void cycleRepeat() {
    final nextMode = switch (state.queue.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(queue: state.queue.setRepeat(nextMode));
  }

  Future<void> seek(Duration requested) async {
    final duration = state.duration;
    final target = duration > Duration.zero
        ? Duration(
            milliseconds: requested.inMilliseconds.clamp(
              0,
              duration.inMilliseconds,
            ),
          )
        : (requested.isNegative ? Duration.zero : requested);
    try {
      await _engine.seek(target);
      state = state.copyWith(position: target);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<void> setVolume(double value) async {
    final volume = value.clamp(0, 1).toDouble();
    try {
      await _engine.setVolume(volume);
      state = state.copyWith(volume: volume);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<void> selectOutputDevice(String id) async {
    try {
      await _engine.selectOutputDevice(id);
      state = state.copyWith(clearAudioDeviceNotice: true);
    } catch (error, stackTrace) {
      developer.log(
        'Could not switch the audio output device.',
        name: 'cadence.playback',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        audioDeviceNotice: 'Could not switch to that audio device.',
      );
    }
  }

  Future<void> _handleOutputDevices(List<AudioOutputDevice> devices) async {
    final ids = devices.map((device) => device.id).toSet();
    if (!_outputDeviceSnapshotLoaded) {
      _outputDeviceSnapshotLoaded = true;
      _availableOutputDeviceIds = ids;
      return;
    }
    final previousIds = _availableOutputDeviceIds;
    final selected = state.selectedAudioOutput;
    _availableOutputDeviceIds = ids;
    if (!selected.isAutomatic &&
        previousIds.contains(selected.id) &&
        !ids.contains(selected.id)) {
      _disconnectedOutputDeviceId = selected.id;
      try {
        await _engine.selectOutputDevice('auto');
        state = state.copyWith(
          selectedAudioOutput: _automaticAudioDevice,
          audioDeviceNotice:
              'Audio device disconnected. Switched to system output.',
        );
      } catch (error, stackTrace) {
        developer.log(
          'Audio output device disconnected and fallback failed.',
          name: 'cadence.playback',
          error: error,
          stackTrace: stackTrace,
        );
        state = state.copyWith(
          audioDeviceNotice:
              'Audio device disconnected. Select another output in Settings.',
        );
      }
      return;
    }
    final disconnectedId = _disconnectedOutputDeviceId;
    if (disconnectedId != null &&
        !previousIds.contains(disconnectedId) &&
        ids.contains(disconnectedId)) {
      final reconnected = devices.firstWhere(
        (device) => device.id == disconnectedId,
      );
      state = state.copyWith(
        audioDeviceNotice:
            '${reconnected.displayName} is available again. Select it in Settings to switch back.',
      );
      _disconnectedOutputDeviceId = null;
    }
  }

  Future<void> _openCurrent({required bool play}) async {
    final song = state.currentSong;
    if (song == null) {
      state = state.copyWith(isLoading: false, isPlaying: false);
      return;
    }
    try {
      await _engine.open(song.path, play: play);
      state = state.copyWith(isLoading: false, clearError: true);
      if (play && !song.isOnline) {
        await _recordPlay(song.id);
      }
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<void> _recordPlay(String songId) async {
    try {
      _activeHistoryId = await ref
          .read(localLibraryRepositoryProvider)
          .markPlayed(songId);
      _activeHistorySongId = songId;
      _sessionMaxPositionMillis = 0;
      if (!_disposed) ref.invalidate(recentlyPlayedSongsProvider);
    } catch (error, stackTrace) {
      developer.log(
        'Could not save local playback history.',
        name: 'cadence.playback',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _finishSession({required bool interrupted}) async {
    final historyId = _activeHistoryId;
    final songId = _activeHistorySongId;
    if (historyId == null || songId == null) return;
    _activeHistoryId = null;
    _activeHistorySongId = null;
    final durationMillis = state.duration.inMilliseconds;
    final completion = durationMillis <= 0
        ? 0.0
        : _sessionMaxPositionMillis / durationMillis * 100;
    try {
      await ref
          .read(localLibraryRepositoryProvider)
          .finishPlaybackSession(
            historyId: historyId,
            songId: songId,
            playedMillis: _sessionMaxPositionMillis,
            durationMillis: durationMillis,
            skipped: interrupted && completion < 80,
          );
    } catch (error, stackTrace) {
      developer.log(
        'Could not save local playback statistics.',
        name: 'cadence.playback',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _reportError(Object error, StackTrace stackTrace) {
    developer.log(
      'Local playback operation failed.',
      name: 'cadence.playback',
      error: error,
      stackTrace: stackTrace,
    );
    if (!_disposed) {
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        error: 'This track could not be played. Check the file or your internet connection and try again.',
      );
    }
  }
}
