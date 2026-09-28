import 'dart:math';

import 'package:cadence_music/features/library/domain/song.dart';
import 'package:cadence_music/features/playback/domain/playback_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final songs = [
    _song('a', 'A'),
    _song('b', 'B'),
    _song('c', 'C'),
    _song('d', 'D'),
  ];

  test('insert-next leaves the current item intact and queues immediately after it', () {
    final queue = PlaybackQueue(songs: songs, currentIndex: 1).insertNext(_song('x', 'X'));
    expect(queue.currentSong?.title, 'B');
    expect(queue.songs.map((song) => song.title), ['A', 'B', 'X', 'C', 'D']);
  });

  test('repeat modes define deterministic next and previous behavior', () {
    final normal = PlaybackQueue(songs: songs.take(2).toList(), currentIndex: 1);
    expect(normal.next(), isNull);
    expect(normal.previous()?.currentSong?.title, 'A');

    final repeatAll = normal.setRepeat(RepeatMode.all);
    expect(repeatAll.next()?.currentSong?.title, 'A');
    expect(repeatAll.previous()?.currentSong?.title, 'A');

    final repeatOne = normal.setRepeat(RepeatMode.one);
    expect(repeatOne.next()?.currentSong?.title, 'B');
  });

  test('shuffle keeps the current song selected and toggle restores original order', () {
    final queue = PlaybackQueue(songs: songs, currentIndex: 2);
    final shuffled = queue.toggleShuffle(random: Random(7));
    expect(shuffled.shuffled, isTrue);
    expect(shuffled.currentIndex, 0);
    expect(shuffled.currentSong?.title, 'C');
    expect(shuffled.songs.toSet(), songs.toSet());

    final restored = shuffled.toggleShuffle();
    expect(restored.shuffled, isFalse);
    expect(restored.currentSong?.title, 'C');
  });

  test('reorder tracks while preserving the currently selected song', () {
    final queue = PlaybackQueue(songs: songs, currentIndex: 2).move(0, 3);
    expect(queue.songs.map((song) => song.title), ['B', 'C', 'D', 'A']);
    expect(queue.currentSong?.title, 'C');
    expect(queue.currentIndex, 1);
  });

  test('removing the current item selects the next available item', () {
    final queue = PlaybackQueue(songs: songs.take(3).toList(), currentIndex: 1).removeAt(1);
    expect(queue.currentSong?.title, 'C');
    expect(queue.songs.map((song) => song.title), ['A', 'C']);
  });
}

Song _song(String id, String title) => Song(
  id: id,
  path: '/music/$id.mp3',
  title: title,
  modifiedAtMillis: 1,
  fileSizeBytes: 1,
  addedAtMillis: 1,
);
