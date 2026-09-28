import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/product_config.dart';
import '../../../core/database/repository_providers.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../library/presentation/library_page.dart';
import '../../playback/application/playback_controller.dart';
import '../../playback/presentation/now_playing_dialog.dart';
import '../../playback/presentation/queue_page.dart';
import '../../playlists/presentation/playlists_page.dart';
import '../../search/presentation/search_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../application/shell_state.dart';
import 'command_palette.dart';
import 'empty_page.dart';
import 'home_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    _searchFocusNode.requestFocus();
  }

  void _openCommandPalette() {
    showDialog<void>(
      context: context,
      builder: (_) => const CommandPaletteDialog(),
    );
  }

  void _submitSearch(String query) {
    final normalized = query.trim();
    ref.read(searchQueryProvider.notifier).update(normalized);
    ref.read(destinationProvider.notifier).select(AppDestination.search);
    if (normalized.isNotEmpty) {
      unawaited(
        ref.read(localLibraryRepositoryProvider).addRecentSearch(normalized),
      );
      ref.invalidate(recentSearchesProvider);
    }
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(destinationProvider);
    final size = MediaQuery.sizeOf(context);
    final extendedSidebar = size.width >= 1180;
    ref.listen(searchQueryProvider, (previous, next) {
      if (_searchController.text != next) {
        _searchController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });
    ref.listen(
      playbackControllerProvider.select((state) => state.audioDeviceNotice),
      (previous, next) {
        if (next != null && next != previous) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(next)));
        }
      },
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openSearch,
        const SingleActivator(
          LogicalKeyboardKey.keyP,
          control: true,
          shift: true,
        ): _openCommandPalette,
        const SingleActivator(
          LogicalKeyboardKey.keyP,
          meta: true,
          shift: true,
        ): _openCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.library),
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.library),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchController.text.isNotEmpty) {
            _searchController.clear();
            ref.read(searchQueryProvider.notifier).clear();
          }
          _searchFocusNode.unfocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                _Sidebar(extended: extendedSidebar),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        destination: destination,
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onQueryChanged: (value) => ref
                            .read(searchQueryProvider.notifier)
                            .update(value),
                        onSearchSubmitted: _submitSearch,
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(context).dividerColor
                            .withValues(alpha: .52),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, .015),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: _pageFor(destination),
                        ),
                      ),
                      const _MiniPlayer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageFor(AppDestination destination) {
    return switch (destination) {
      AppDestination.home => HomePage(
        key: const ValueKey(AppDestination.home),
        onOpenLibrary: () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.library),
        onOpenPlaylists: () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.playlists),
      ),
      AppDestination.settings => SettingsPage(
        key: const ValueKey(AppDestination.settings),
        onOpenLibrary: () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.library),
      ),
      AppDestination.library => const LibraryPage(
        key: ValueKey(AppDestination.library),
      ),
      AppDestination.playlists => const PlaylistsPage(
        key: ValueKey(AppDestination.playlists),
      ),
      AppDestination.queue => QueuePage(
        key: const ValueKey(AppDestination.queue),
        onOpenLibrary: () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.library),
      ),
      AppDestination.search => const SearchPage(
        key: ValueKey(AppDestination.search),
      ),
      AppDestination.about => const AboutPage(
        key: ValueKey(AppDestination.about),
      ),
      _ => EmptyPage(
        key: ValueKey(destination),
        destination: destination,
        query: ref.watch(searchQueryProvider),
        onOpenLibrary: () => ref
            .read(destinationProvider.notifier)
            .select(AppDestination.library),
      ),
    };
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.destination,
    required this.controller,
    required this.focusNode,
    required this.onQueryChanged,
    required this.onSearchSubmitted,
  });

  final AppDestination destination;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final searchQuery = ref.watch(searchQueryProvider);
    final extended = MediaQuery.sizeOf(context).width >= 1180;
    return SizedBox(
      height: 76,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: extended ? 32 : 22),
        child: Row(
          children: [
            if (!extended) ...[
              Text(
                _title(destination),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 20),
            ] else ...[
              Icon(Icons.graphic_eq_rounded, size: 17, color: scheme.primary),
              const SizedBox(width: 9),
              Text(
                _title(destination),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 28),
            ],
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 570),
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onQueryChanged,
                    onSubmitted: onSearchSubmitted,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search your library or catalog',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchQuery.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  _shortcutLabel(context),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                controller.clear();
                                onQueryChanged('');
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            PopupMenuButton<ThemeMode>(
              tooltip: 'Appearance',
              initialValue: ref.watch(appearanceModeProvider),
              onSelected: ref.read(appearanceModeProvider.notifier).setMode,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ThemeMode.system,
                  child: Text('System appearance'),
                ),
                PopupMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light appearance'),
                ),
                PopupMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark appearance'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  ref.watch(appearanceModeProvider) == ThemeMode.light
                      ? Icons.light_mode_outlined
                      : ref.watch(appearanceModeProvider) == ThemeMode.system
                      ? Icons.brightness_auto_rounded
                      : Icons.dark_mode_outlined,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'About ${ProductConfig.name}',
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => ref
                    .read(destinationProvider.notifier)
                    .select(AppDestination.about),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: scheme.primary.withValues(alpha: .17),
                  child: Text(
                    'C',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortcutLabel(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.macOS ? '⌘ K' : 'Ctrl K';
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(destinationProvider);
    final scheme = Theme.of(context).colorScheme;
    final width = extended ? 238.0 : 76.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111215)
            : const Color(0xFFEDEAE6),
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .48),
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 76,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: extended ? 20 : 18),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.asset(
                      'assets/branding/cadence_icon.png',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (extended) ...[
                    const SizedBox(width: 12),
                    Text(
                      ProductConfig.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (extended)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 8),
              child: Row(
                children: [
                  Icon(Icons.waves_rounded, size: 14, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'YOUR SPACE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 10),
          for (final item in _primaryItems)
            _NavItem(item: item, selected: selected, extended: extended),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 18 : 14,
              vertical: 13,
            ),
            child: Divider(
              color: Theme.of(context).dividerColor.withValues(alpha: .55),
            ),
          ),
          for (final item in _secondaryItems)
            _NavItem(item: item, selected: selected, extended: extended),
          const Spacer(),
          if (extended)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Text(
                'Offline-first · preview build',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  static const _primaryItems = <_NavEntry>[
    _NavEntry(AppDestination.home, 'Home', Icons.home_rounded),
    _NavEntry(AppDestination.explore, 'Explore', Icons.explore_outlined),
    _NavEntry(AppDestination.library, 'Library', Icons.library_music_outlined),
    _NavEntry(AppDestination.playlists, 'Playlists', Icons.queue_music_rounded),
    _NavEntry(AppDestination.queue, 'Queue', Icons.playlist_play_rounded),
    _NavEntry(AppDestination.downloads, 'Downloads', Icons.download_outlined),
  ];

  static const _secondaryItems = <_NavEntry>[
    _NavEntry(AppDestination.settings, 'Settings', Icons.settings_outlined),
    _NavEntry(AppDestination.about, 'About', Icons.info_outline_rounded),
  ];
}

class _NavEntry {
  const _NavEntry(this.destination, this.title, this.icon);
  final AppDestination destination;
  final String title;
  final IconData icon;
}

class _NavItem extends ConsumerWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.extended,
  });

  final _NavEntry item;
  final AppDestination selected;
  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = selected == item.destination;
    final scheme = Theme.of(context).colorScheme;
    final button = InkWell(
      onTap: () =>
          ref.read(destinationProvider.notifier).select(item.destination),
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 44,
        margin: EdgeInsets.symmetric(
          horizontal: extended ? 12 : 10,
          vertical: 2,
        ),
        padding: EdgeInsets.symmetric(horizontal: extended ? 13 : 0),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withValues(alpha: .13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: active
              ? Border.all(color: scheme.primary.withValues(alpha: .16))
              : null,
        ),
        child: Row(
          mainAxisAlignment: extended
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 20,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
            if (extended) ...[
              const SizedBox(width: 12),
              Text(
                item.title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Tooltip(message: item.title, child: button);
  }
}

class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final song = playback.currentSong;
    final progress = playback.duration.inMilliseconds <= 0
        ? 0.0
        : playback.position.inMilliseconds
              .clamp(0, playback.duration.inMilliseconds)
              .toDouble();
    final max = playback.duration.inMilliseconds > 0
        ? playback.duration.inMilliseconds.toDouble()
        : 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: GlassSurface(
        radius: 17,
        blur: 8,
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => const NowPlayingDialog(),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: song?.artworkPath == null
                          ? Container(
                              color: scheme.primary.withValues(alpha: .13),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: scheme.primary,
                                size: 22,
                              ),
                            )
                          : Image.file(
                              File(song!.artworkPath!),
                              fit: BoxFit.cover,
                              cacheWidth: 140,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: scheme.primary.withValues(
                                      alpha: .13,
                                    ),
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      color: scheme.primary,
                                      size: 22,
                                    ),
                                  ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => const NowPlayingDialog(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song?.title ?? 'Nothing playing yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song?.displayArtist ??
                              'Add local music to get started',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous track',
                  onPressed: song == null ? null : controller.previous,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton(
                  tooltip: playback.isPlaying ? 'Pause' : 'Play',
                  onPressed: song == null ? null : controller.togglePlayPause,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.primary.withValues(alpha: .12),
                  ),
                  icon: Icon(
                    playback.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Next track',
                  onPressed: song == null ? null : controller.next,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                IconButton(
                  tooltip: playback.volume == 0 ? 'Unmute' : 'Mute',
                  onPressed: () =>
                      controller.setVolume(playback.volume == 0 ? .8 : 0),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    playback.volume == 0
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 16,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 4,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                ),
                child: Slider(
                  value: progress,
                  max: max,
                  onChanged: song == null || playback.duration <= Duration.zero
                      ? null
                      : (value) => controller.seek(
                          Duration(milliseconds: value.round()),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _title(AppDestination destination) => switch (destination) {
  AppDestination.home => 'Home',
  AppDestination.explore => 'Explore',
  AppDestination.library => 'Library',
  AppDestination.playlists => 'Playlists',
  AppDestination.queue => 'Queue',
  AppDestination.downloads => 'Downloads',
  AppDestination.search => 'Search',
  AppDestination.settings => 'Settings',
  AppDestination.about => 'About',
};
