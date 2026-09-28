import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/library_controller.dart';
import '../../library/application/library_search_providers.dart';
import '../../library/presentation/song_list_tile.dart';
import '../../playback/application/playback_controller.dart';
import '../../playlists/application/playlist_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({
    required this.onOpenLibrary,
    required this.onOpenPlaylists,
    super.key,
  });

  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenPlaylists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final library = ref.watch(libraryControllerProvider);
    final recentlyPlayed = ref.watch(recentlyPlayedSongsProvider);
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxWidth >= 920;
        return SingleChildScrollView(
          key: const PageStorageKey<String>('home-scroll'),
          padding: EdgeInsets.fromLTRB(
            roomy ? 36 : 24,
            30,
            roomy ? 36 : 24,
            30,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1370),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: .15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'LOCAL-FIRST LISTENING',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    letterSpacing: .8,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (roomy)
                        Text(
                          'A desktop listening space',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Make room for\nyour music.',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.3,
                      height: 1.04,
                    ),
                  ),
                  const SizedBox(height: 11),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 610),
                    child: Text(
                      'A quieter, considered home for the music you already own. Your library stays yours—and works offline.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 27),
                  _WelcomePanel(
                    roomy: roomy,
                    onOpenLibrary: onOpenLibrary,
                    hasTracks: library.trackCount > 0,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'Start with your collection',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.3,
                              ),
                        ),
                      ),
                      Text(
                        'YOUR MUSIC, YOUR DEVICE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: .7,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, rowConstraints) {
                      final count = rowConstraints.maxWidth >= 960
                          ? 3
                          : rowConstraints.maxWidth >= 600
                          ? 2
                          : 1;
                      const gap = 14.0;
                      final width =
                          (rowConstraints.maxWidth - gap * (count - 1)) / count;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          _CollectionCard(
                            width: width,
                            icon: Icons.library_music_outlined,
                            title: 'Local library',
                            subtitle: library.roots.isEmpty
                                ? 'Add a local folder'
                                : '${library.roots.length} music ${library.roots.length == 1 ? 'folder' : 'folders'}',
                            count:
                                '${library.trackCount} ${library.trackCount == 1 ? 'track' : 'tracks'}',
                            accent: const Color(0xFFDBA47E),
                            onTap: onOpenLibrary,
                          ),
                          _CollectionCard(
                            width: width,
                            icon: Icons.favorite_border_rounded,
                            title: 'Your favorites',
                            subtitle: 'Save the songs you love',
                            count:
                                '${library.favoriteCount} ${library.favoriteCount == 1 ? 'favorite' : 'favorites'}',
                            accent: const Color(0xFFD28B93),
                            onTap: () {
                              ref.read(favoritesOnlyProvider.notifier).state =
                                  true;
                              onOpenLibrary();
                            },
                          ),
                          _CollectionCard(
                            width: width,
                            icon: Icons.queue_music_rounded,
                            title: 'Your playlists',
                            subtitle: 'Build a soundtrack for anything',
                            count:
                                '${playlists.length} ${playlists.length == 1 ? 'playlist' : 'playlists'}',
                            accent: const Color(0xFFAFA0D1),
                            onTap: onOpenPlaylists,
                          ),
                        ],
                      );
                    },
                  ),
                  if (recentlyPlayed.valueOrNull?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 26),
                    Text(
                      'Recently played',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 9),
                    for (final song in recentlyPlayed.valueOrNull!.take(5))
                      SongListTile(
                        song: song,
                        compact: true,
                        onTap: () => ref
                            .read(playbackControllerProvider.notifier)
                            .playSong(song),
                      ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your music stays on your computer. No account or network connection required.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.roomy,
    required this.onOpenLibrary,
    required this.hasTracks,
  });
  final bool roomy;
  final VoidCallback onOpenLibrary;
  final bool hasTracks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'A listening space that feels like yours',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.5),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Add a music folder or individual tracks. Cadence reads audio in place and keeps your library on this computer.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.55),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.tonalIcon(
          onPressed: onOpenLibrary,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(hasTracks ? 'Open your library' : 'Add local music'),
        ),
      ],
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 238),
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF211D1B),
      child: Row(
        children: [
          Expanded(child: copy),
          if (roomy) ...[
            const SizedBox(width: 24),
            const _SoundArtwork(compact: true),
          ],
        ],
      ),
    );
  }
}

class _SoundArtwork extends StatelessWidget {
  const _SoundArtwork({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 145.0 : 188.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * .88,
            height: size * .88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * .23),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFDCA17B),
                  Color(0xFF754C59),
                  Color(0xFF343144),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB67660).withValues(alpha: .28),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CustomPaint(painter: _WavePainter()),
          ),
          Positioned(
            top: size * .09,
            right: size * .08,
            child: Container(
              width: size * .32,
              height: size * .32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .15),
                border: Border.all(color: Colors.white.withValues(alpha: .3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .48, size.height * .53);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 5; index++) {
      final inset = index * size.width * .075;
      paint
        ..strokeWidth = 1.2 + index * .45
        ..color = Colors.white.withValues(alpha: .16 + index * .025);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: size.width * .66 - inset,
            height: size.height * .68 - inset,
          ),
          Radius.circular(size.width),
        ),
        paint,
      );
    }
    final bars = [0.26, 0.44, 0.7, 0.52, 0.34];
    final barPaint = Paint()
      ..color = const Color(0xFFFFE3C7).withValues(alpha: .88)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * .025;
    for (var index = 0; index < bars.length; index++) {
      final x = size.width * (.32 + index * .09);
      final height = size.height * bars[index];
      canvas.drawLine(
        Offset(x, center.dy - height / 2),
        Offset(x, center.dy + height / 2),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.accent,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final String count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .62),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        count,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: .82),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: scheme.onSurfaceVariant.withValues(alpha: .7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
