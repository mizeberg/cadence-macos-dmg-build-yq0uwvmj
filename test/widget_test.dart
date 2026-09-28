import 'dart:async';

import 'package:cadence_music/app/cadence_app.dart';
import 'package:cadence_music/core/database/app_database.dart';
import 'package:cadence_music/core/database/database_provider.dart';
import 'package:cadence_music/core/database/repository_providers.dart';
import 'package:cadence_music/core/database/settings_repository.dart';
import 'package:cadence_music/core/database/settings_repository_provider.dart';
import 'package:cadence_music/core/theme/ui_preferences.dart';
import 'package:cadence_music/features/library/application/library_controller.dart';
import 'package:cadence_music/features/library/application/library_search_providers.dart';
import 'package:cadence_music/features/library/domain/song.dart';
import 'package:cadence_music/features/library/data/local_library_repository.dart';
import 'package:cadence_music/features/playback/data/audio_engine.dart';
import 'package:cadence_music/features/playback/data/audio_output_models.dart';
import 'package:cadence_music/features/playlists/application/playlist_providers.dart';
import 'package:cadence_music/features/playlists/domain/playlist.dart';
import 'package:cadence_music/features/search/presentation/search_page.dart'
    show recentSearchesProvider;
import 'package:cadence_music/features/shell/application/shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Future<void> pumpUi(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpCadence(WidgetTester tester) async {
    final audioEngine = _FakeAudioEngine();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await audioEngine.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioEngineProvider.overrideWithValue(audioEngine),
          localLibraryRepositoryProvider.overrideWithValue(
            _FakeLocalLibraryRepository(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          libraryControllerProvider.overrideWith(_FakeLibraryController.new),
          recentlyPlayedSongsProvider.overrideWith(
            (ref) async => const <Song>[],
          ),
          librarySearchResultsProvider.overrideWith(
            (ref, query) async => const <Song>[],
          ),
          playlistsProvider.overrideWith((ref) async => const <Playlist>[]),
          recentSearchesProvider.overrideWith((ref) async => const <String>[]),
          performanceModeProvider.overrideWith((ref) async => false),
          reduceMotionProvider.overrideWith((ref) async => false),
        ],
        child: const CadenceApp(),
      ),
    );
    await pumpUi(tester);
  }

  testWidgets('home presents functional local music actions', (tester) async {
    await pumpCadence(tester);

    expect(find.text('Make room for\nyour music.'), findsOneWidget);
    expect(find.text('LOCAL-FIRST LISTENING'), findsOneWidget);
    expect(find.text('Nothing playing yet'), findsOneWidget);
    expect(find.text('Add local music'), findsOneWidget);
  });

  testWidgets('library provides folder and file import actions', (
    tester,
  ) async {
    await pumpCadence(tester);

    await tester.tap(find.byTooltip('Library').first);
    await pumpUi(tester);

    expect(find.text('Your library'), findsOneWidget);
    expect(find.text('Add your music folder'), findsOneWidget);
    expect(find.text('Add files'), findsOneWidget);
    expect(find.text('Add folder'), findsOneWidget);
  });

  testWidgets('playlist screen exposes local playlist creation', (
    tester,
  ) async {
    await pumpCadence(tester);

    await tester.tap(find.byTooltip('Playlists').first);
    await pumpUi(tester);

    expect(find.text('Make a playlist of your own'), findsOneWidget);
    expect(find.text('New playlist'), findsOneWidget);
  });

  testWidgets('queue screen explains how to start a local queue', (
    tester,
  ) async {
    await pumpCadence(tester);

    await tester.tap(find.byTooltip('Queue').first);
    await pumpUi(tester);

    expect(find.text('Your queue is empty'), findsOneWidget);
    expect(find.text('Browse library'), findsOneWidget);
  });

  testWidgets('settings shows theme, real volume, and privacy controls', (
    tester,
  ) async {
    await pumpCadence(tester);

    await tester.tap(find.byTooltip('Settings').first);
    await pumpUi(tester);

    final settingsScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .last;
    await tester.scrollUntilVisible(
      find.text('Playback volume'),
      220,
      scrollable: settingsScroll,
    );
    expect(find.text('Playback volume'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Output device'),
      220,
      scrollable: settingsScroll,
    );
    expect(find.text('Output device'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Manage library'),
      220,
      scrollable: settingsScroll,
    );
    expect(find.text('Manage library'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Your files stay yours'),
      220,
      scrollable: settingsScroll,
    );
    expect(find.text('Your files stay yours'), findsOneWidget);
  });

  testWidgets('search submits to the local index and exposes clear action', (
    tester,
  ) async {
    await pumpCadence(tester);

    await tester.enterText(find.byType(TextField).first, 'ambient');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUi(tester);

    expect(find.text('No tracks found'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsOneWidget);
  });

  testWidgets('appearance menu offers all Material 3 theme modes', (
    tester,
  ) async {
    await pumpCadence(tester);

    await tester.tap(find.byTooltip('Appearance'));
    await pumpUi(tester);

    expect(find.text('System appearance'), findsOneWidget);
    expect(find.text('Light appearance'), findsOneWidget);
    expect(find.text('Dark appearance'), findsOneWidget);

    await tester.tap(find.text('Light appearance'));
    await pumpUi(tester);
    expect(find.text('Make room for\nyour music.'), findsOneWidget);
  });

  testWidgets('shell lays out at standard and ultra-wide desktop sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    tester.view.physicalSize = const Size(1280, 720);
    await pumpCadence(tester);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(2560, 1440);
    await pumpUi(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+K focuses global search', (tester) async {
    await pumpCadence(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    final searchField = tester.widget<EditableText>(find.byType(EditableText));
    expect(searchField.focusNode.hasPrimaryFocus, isTrue);
  });

  test('appearance state can be changed independently of widgets', () async {
    final database = await AppDatabase.open(inMemory: true);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    expect(container.read(appearanceModeProvider), ThemeMode.dark);
    container.read(appearanceModeProvider.notifier).setMode(ThemeMode.system);
    expect(container.read(appearanceModeProvider), ThemeMode.system);
  });
}

class _FakeLibraryController extends LibraryController {
  @override
  LibraryViewState build() => const LibraryViewState();
}

class _FakeLocalLibraryRepository extends LocalLibraryRepository {
  _FakeLocalLibraryRepository() : super(_UnusedDatabase());

  @override
  Future<void> addRecentSearch(String query, {int maxItems = 8}) async {}
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository() : super(_UnusedDatabase());

  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> putString(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}
}

class _UnusedDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Widget tests must not access SQLite.');
}

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
    _position.add(Duration.zero);
    _duration.add(const Duration(minutes: 3));
    _playing.add(play);
  }

  @override
  Future<void> play() async => _playing.add(true);
  @override
  Future<void> pause() async => _playing.add(false);
  @override
  Future<void> stop() async => _playing.add(false);
  @override
  Future<void> seek(Duration position) async => _position.add(position);
  @override
  Future<void> setVolume(double volume) async => _volume.add(volume);
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
