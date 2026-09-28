import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/settings_repository_provider.dart';

enum AppDestination {
  home,
  explore,
  library,
  playlists,
  queue,
  downloads,
  search,
  settings,
  about,
}

final destinationProvider =
    NotifierProvider<DestinationController, AppDestination>(
      DestinationController.new,
    );

class DestinationController extends Notifier<AppDestination> {
  @override
  AppDestination build() => AppDestination.home;

  void select(AppDestination destination) => state = destination;
}

final appearanceModeProvider =
    NotifierProvider<AppearanceModeController, ThemeMode>(
      AppearanceModeController.new,
    );

class AppearanceModeController extends Notifier<ThemeMode> {
  AppearanceModeController({this.initialMode = ThemeMode.dark});

  final ThemeMode initialMode;

  @override
  ThemeMode build() => initialMode;

  void setMode(ThemeMode mode) {
    state = mode;
    unawaited(
      ref
          .read(settingsRepositoryProvider)
          .putString('appearance.theme', mode.name),
    );
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
  void clear() => state = '';
}
