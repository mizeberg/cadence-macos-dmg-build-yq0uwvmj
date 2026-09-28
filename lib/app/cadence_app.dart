import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';

import '../core/config/product_config.dart';
import '../core/theme/app_theme.dart';
import '../features/shell/application/shell_state.dart';
import '../features/shell/presentation/app_shell.dart';

class CadenceApp extends ConsumerWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appearanceModeProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: ProductConfig.name,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(dynamicAccent: lightDynamic?.primary),
          darkTheme: AppTheme.dark(dynamicAccent: darkDynamic?.primary),
          themeMode: mode,
          home: const AppShell(),
        );
      },
    );
  }
}
