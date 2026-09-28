import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider).connection),
);
