import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/song.dart';
import 'audio_info_dialog.dart';
import 'song_context_menu.dart';

class SongListTile extends StatelessWidget {
  const SongListTile({
    required this.song,
    required this.onTap,
    this.trailing,
    this.indexLabel,
    this.selected = false,
    this.compact = false,
    super.key,
  });

  final Song song;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? indexLabel;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final artworkSize = compact ? 38.0 : 46.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 12,
            vertical: compact ? 6 : 8,
          ),
          child: Row(
            children: [
              if (indexLabel != null) ...[
                SizedBox(
                  width: 32,
                  child: Text(
                    indexLabel!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: artworkSize,
                  height: artworkSize,
                  child: _artwork(song, scheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurface,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        if (song.isLossless)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Tooltip(
                              message:
                                  'Source format verified as ${song.isHiResLossless ? 'high-resolution lossless' : 'lossless'}. Output may still use system processing.',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => showAudioInfoDialog(context, song),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.tertiaryContainer.withValues(
                                      alpha: .65,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    song.isHiResLossless
                                        ? 'HI-RES'
                                        : 'LOSSLESS',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: scheme.onTertiaryContainer,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: .35,
                                          fontSize: 9,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.isOnline
                          ? '${song.displayArtist} · ${song.sourceName}${song.licenseLabel == null ? '' : ' · ${song.licenseLabel}'}'
                          : song.displayArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: Text(
                    song.displayAlbum,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 52,
                  child: Text(
                    _formatDuration(song.duration),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 5), trailing!],
              const SizedBox(width: 2),
              if (!song.isOnline) SongContextMenu(song: song),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return duration <= Duration.zero ? '—' : '$minutes:$seconds';
  }
}

Widget _artwork(Song song, Color fallbackColor) {
  final path = song.artworkPath;
  if (path == null) return _ArtworkFallback(color: fallbackColor);
  final uri = Uri.tryParse(path);
  if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
    return Image.network(
      path,
      fit: BoxFit.cover,
      cacheWidth: 180,
      errorBuilder: (context, error, stackTrace) =>
          _ArtworkFallback(color: fallbackColor),
    );
  }
  return Image.file(
    File(path),
    fit: BoxFit.cover,
    cacheWidth: 180,
    errorBuilder: (context, error, stackTrace) =>
        _ArtworkFallback(color: fallbackColor),
  );
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    color: color.withValues(alpha: .13),
    alignment: Alignment.center,
    child: Icon(Icons.music_note_rounded, size: 20, color: color),
  );
}
