import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/settings_repository_provider.dart';

final reduceMotionProvider = FutureProvider<bool>((ref) async {
  final value = await ref
      .watch(settingsRepositoryProvider)
      .getString('appearance.reduce_motion');
  return value == 'true';
});

final performanceModeProvider = FutureProvider<bool>((ref) async {
  final value = await ref
      .watch(settingsRepositoryProvider)
      .getString('appearance.performance_mode');
  return value == 'true';
});

Future<void> setUiPreference(WidgetRef ref, String key, bool value) async {
  await ref.read(settingsRepositoryProvider).putString(key, value.toString());
  if (key == 'appearance.reduce_motion') {
    ref.invalidate(reduceMotionProvider);
  } else if (key == 'appearance.performance_mode') {
    ref.invalidate(performanceModeProvider);
  }
}
