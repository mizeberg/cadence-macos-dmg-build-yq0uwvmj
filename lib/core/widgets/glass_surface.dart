import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ui_preferences.dart';

enum GlassLevel { card, navigation, dialog }

/// A clipped, bounded glass treatment. Avoid using it as a repeating row style.
class GlassSurface extends ConsumerWidget {
  const GlassSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.blur,
    this.tint,
    this.border = true,
    this.level = GlassLevel.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? blur;
  final Color? tint;
  final bool border;
  final GlassLevel level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reducedMotion =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        (ref.watch(reduceMotionProvider).valueOrNull ?? false);
    final performance = ref.watch(performanceModeProvider).valueOrNull ?? false;
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final blurRadius = reducedMotion || performance
        ? 0.0
        : blur ??
              switch (level) {
                GlassLevel.card => 7.0,
                GlassLevel.navigation => 12.0,
                GlassLevel.dialog => 18.0,
              };
    final opacity = performance
        ? .96
        : switch (level) {
            GlassLevel.card => brightness == Brightness.dark ? .80 : .88,
            GlassLevel.navigation => brightness == Brightness.dark ? .86 : .91,
            GlassLevel.dialog => brightness == Brightness.dark ? .94 : .96,
          };
    final surfaceColor = (tint ?? scheme.surfaceContainer).withValues(
      alpha: tint == null ? opacity : tint!.a,
    );

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: border
            ? Border.all(
                color: scheme.outlineVariant.withValues(
                  alpha: performance ? .85 : .65,
                ),
              )
            : null,
        boxShadow: performance
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: brightness == Brightness.dark ? .15 : .07,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (blurRadius > 0) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
        child: surface,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: surface,
    );
  }
}

class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) =>
      GlassSurface(level: GlassLevel.card, padding: padding, child: child);
}

class LiquidGlassNavigation extends StatelessWidget {
  const LiquidGlassNavigation({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassSurface(
    level: GlassLevel.navigation,
    padding: EdgeInsets.zero,
    radius: 18,
    child: child,
  );
}

class LiquidGlassPlayer extends StatelessWidget {
  const LiquidGlassPlayer({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassSurface(
    level: GlassLevel.navigation,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    radius: 16,
    child: child,
  );
}

class LiquidGlassToolbar extends StatelessWidget {
  const LiquidGlassToolbar({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassSurface(
    level: GlassLevel.navigation,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    radius: 14,
    child: child,
  );
}

class LiquidGlassDialog extends StatelessWidget {
  const LiquidGlassDialog({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassSurface(
    level: GlassLevel.dialog,
    padding: const EdgeInsets.all(20),
    radius: 24,
    child: child,
  );
}
