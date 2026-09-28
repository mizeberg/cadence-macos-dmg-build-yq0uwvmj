import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app/cadence_app.dart';
import 'core/config/product_config.dart';
import 'core/config/window_bounds_persistence.dart';
import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/database/settings_repository.dart';
import 'features/shell/application/shell_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final database = await AppDatabase.open();
  final settings = SettingsRepository(database.connection);
  final savedMode = await settings.getString('appearance.theme');
  final savedWindowBounds = WindowBoundsPersistence.decode(
    await settings.getString('window.bounds'),
  );
  final mode = switch (savedMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1440, 900),
        minimumSize: Size(860, 600),
        center: true,
        title: ProductConfig.name,
        titleBarStyle: TitleBarStyle.normal,
      ),
      () async {
        if (savedWindowBounds != null) {
          await windowManager.setBounds(savedWindowBounds);
        }
        await windowManager.show();
        await windowManager.focus();
      },
    );
    windowManager.addListener(WindowBoundsPersistence(settings));
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appearanceModeProvider.overrideWith(
          () => AppearanceModeController(initialMode: mode),
        ),
      ],
      child: const CadenceApp(),
    ),
  );
}
