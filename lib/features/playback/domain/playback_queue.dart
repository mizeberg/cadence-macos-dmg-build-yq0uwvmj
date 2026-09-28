import 'dart:math';

import '../../library/domain/song.dart';

enum RepeatMode { off, all, one }

/// User-visible upcoming items. Provider autoplay suggestions are intentionally
/// not mixed into this queue; none are enabled without an authorized source.
class PlaybackQueue {
  PlaybackQueue({
    required List<Song> songs,
    required this.currentIndex,
    this.shuffled = false,
    this.repeatMode = RepeatMode.off,
  }) : songs = List.unmodifiable(songs);

  factory PlaybackQueue.empty() =>
      PlaybackQueue(songs: const [], currentIndex: -1);

  final List<Song> songs;
  final int currentIndex;
  final bool shuffled;
  final RepeatMode repeatMode;

  Song? get currentSong => currentIndex >= 0 && currentIndex < songs.length
      ? songs[currentIndex]
      : null;
  bool get isEmpty => songs.isEmpty;

  PlaybackQueue playAll(List<Song> value, {int startIndex = 0}) {
    if (value.isEmpty) return PlaybackQueue.empty();
    final safeIndex = startIndex.clamp(0, value.length - 1);
    return PlaybackQueue(songs: value, currentIndex: safeIndex);
  }

  PlaybackQueue addAll(Iterable<Song> value) => PlaybackQueue(
    songs: [...songs, ...value],
    currentIndex: currentIndex < 0 && value.isNotEmpty ? 0 : currentIndex,
    shuffled: shuffled,
    repeatMode: repeatMode,
  );

  PlaybackQueue insertNext(Song song) {
    if (isEmpty) return PlaybackQueue(songs: [song], currentIndex: 0);
    final nextIndex = (currentIndex + 1).clamp(0, songs.length);
    final copy = [...songs]..insert(nextIndex, song);
    return PlaybackQueue(
      songs: copy,
      currentIndex: currentIndex,
      shuffled: shuffled,
      repeatMode: repeatMode,
    );
  }

  PlaybackQueue removeAt(int index) {
    if (index < 0 || index >= songs.length) return this;
    final copy = [...songs]..removeAt(index);
    if (copy.isEmpty) return PlaybackQueue.empty();
    var nextCurrent = currentIndex;
    if (index < currentIndex) nextCurrent--;
    if (index == currentIndex) nextCurrent = min(index, copy.length - 1);
    return PlaybackQueue(
      songs: copy,
      currentIndex: nextCurrent,
      shuffled: shuffled,
      repeatMode: repeatMode,
    );
  }

  PlaybackQueue move(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= songs.length || songs.isEmpty) return this;
    final destination = newIndex.clamp(0, songs.length - 1);
    if (oldIndex == destination) return this;
    final copy = [...songs];
    final song = copy.removeAt(oldIndex);
    copy.insert(destination, song);
    var nextCurrent = currentIndex;
    if (currentIndex == oldIndex) {
      nextCurrent = destination;
    } else if (oldIndex < currentIndex && destination >= currentIndex) {
      nextCurrent--;
    } else if (oldIndex > currentIndex && destination <= currentIndex) {
      nextCurrent++;
    }
    return PlaybackQueue(
      songs: copy,
      currentIndex: nextCurrent,
      shuffled: shuffled,
      repeatMode: repeatMode,
    );
  }

  PlaybackQueue select(int index) {
    if (index < 0 || index >= songs.length) return this;
    return PlaybackQueue(
      songs: songs,
      currentIndex: index,
      shuffled: shuffled,
      repeatMode: repeatMode,
    );
  }

  PlaybackQueue toggleShuffle({Random? random}) {
    if (!shuffled && songs.length > 2 && currentSong != null) {
      final rest = [...songs]..removeAt(currentIndex);
      rest.shuffle(random ?? Random.secure());
      return PlaybackQueue(
        songs: [currentSong!, ...rest],
        currentIndex: 0,
        shuffled: true,
        repeatMode: repeatMode,
      );
    }
    return PlaybackQueue(
      songs: songs,
      currentIndex: currentIndex,
      shuffled: false,
      repeatMode: repeatMode,
    );
  }

  PlaybackQueue setRepeat(RepeatMode mode) => PlaybackQueue(
    songs: songs,
    currentIndex: currentIndex,
    shuffled: shuffled,
    repeatMode: mode,
  );

  PlaybackQueue? next() {
    if (isEmpty) return null;
    if (repeatMode == RepeatMode.one) return this;
    if (currentIndex + 1 < songs.length) return select(currentIndex + 1);
    if (repeatMode == RepeatMode.all) return select(0);
    return null;
  }

  PlaybackQueue? previous() {
    if (isEmpty) return null;
    if (currentIndex > 0) return select(currentIndex - 1);
    if (repeatMode == RepeatMode.all) return select(songs.length - 1);
    return select(0);
  }
}
