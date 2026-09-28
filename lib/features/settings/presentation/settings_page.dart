import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/product_config.dart';
import '../../../core/theme/ui_preferences.dart';
import '../../library/application/library_controller.dart';
import '../../online/application/jamendo_providers.dart';
import '../../playback/application/playback_controller.dart';
import '../../../core/database/settings_repository_provider.dart';
import '../../playback/application/audio_engine_providers.dart';
import '../../shell/application/shell_state.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({this.onOpenLibrary, super.key});

  final VoidCallback? onOpenLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(appearanceModeProvider);
    final playback = ref.watch(playbackControllerProvider);
    final library = ref.watch(libraryControllerProvider);
    final reduceMotion = ref.watch(reduceMotionProvider).valueOrNull ?? false;
    final performanceMode =
        ref.watch(performanceModeProvider).valueOrNull ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 42),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.4),
        ),
        const SizedBox(height: 5),
        Text(
          'Shape your listening space and connect music sources.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, 'Appearance'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.brightness_6_outlined, color: scheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  'Choose a look or follow your system setting.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) => ref
                      .read(appearanceModeProvider.notifier)
                      .setMode(selection.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.motion_photos_off_outlined),
                title: const Text('Reduce motion'),
                subtitle: const Text(
                  'Reduce blur transitions and follow system reduced-motion preferences.',
                ),
                value: reduceMotion,
                onChanged: (value) =>
                    setUiPreference(ref, 'appearance.reduce_motion', value),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: const Icon(Icons.speed_rounded),
                title: const Text('Performance mode'),
                subtitle: const Text(
                  'Disable glass blur and decorative shadows for lower-end devices.',
                ),
                value: performanceMode,
                onChanged: (value) =>
                    setUiPreference(ref, 'appearance.performance_mode', value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        _sectionTitle(context, 'Playback'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 15),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.volume_up_outlined, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Playback volume',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${(playback.volume * 100).round()}%',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Slider(
                  value: playback.volume,
                  max: 1,
                  onChanged: ref
                      .read(playbackControllerProvider.notifier)
                      .setVolume,
                ),
                const Divider(height: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _AudioDeviceCard(),
        const SizedBox(height: 10),
        _sectionTitle(context, 'Audio output mode'),
        const SizedBox(height: 10),
        const _AudioOutputModeCard(),
        const SizedBox(height: 10),
        const _StatusTile(
          icon: Icons.graphic_eq_rounded,
          title: 'Audio processing',
          description: 'Equalizer, ReplayGain, normalization, crossfade and automix are not applied. ReplayGain tags may be inspected in Audio Information.',
          badge: 'NO APP DSP',
        ),
        const SizedBox(height: 25),
        _sectionTitle(context, 'Music library'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.library_music_outlined, color: scheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Local collection',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${library.trackCount} indexed tracks · ${library.roots.length} ${library.roots.length == 1 ? 'folder' : 'folders'}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (library.roots.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final root in library.roots)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder_open_outlined),
                      title: Text(
                        root.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        root.lastScanAtMillis == null
                            ? 'Not scanned yet'
                            : 'Last scanned ${_relative(root.lastScanAtMillis!)}',
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: onOpenLibrary,
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('Manage library'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 25),
        _sectionTitle(context, 'Online music'),
        const SizedBox(height: 10),
        const _JamendoSettingsCard(),
        const SizedBox(height: 25),
        _sectionTitle(context, 'Privacy & storage'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              const _StatusTile(
                icon: Icons.lock_outline_rounded,
                title: 'Your files stay yours',
                description: 'Cadence indexes files in place. It does not move, modify, or upload your audio or embedded tags.',
                badge: 'ON THIS DEVICE',
              ),
              const Divider(height: 1, indent: 58),
              const _StatusTile(
                icon: Icons.cloud_off_outlined,
                title: 'Online search is on demand',
                description: 'Search terms are sent to Jamendo only when you select the online catalog. Audio is streamed directly and is not downloaded or added to your local library.',
                badge: 'HTTPS',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Jamendo API access is for non-commercial use under its current API terms. Review each track’s Creative Commons license before reuse. Commercial distribution or monetized use requires permission from Jamendo. The API Client ID is stored in Cadence’s local settings database.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.55),
        ),
      ],
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w700),
  );

  static String _relative(int millis) {
    final ago = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(millis),
    );
    if (ago.inMinutes < 1) return 'just now';
    if (ago.inHours < 1) return '${ago.inMinutes} min ago';
    if (ago.inDays < 1) return '${ago.inHours} hr ago';
    if (ago.inDays < 30) return '${ago.inDays} days ago';
    return '${(ago.inDays / 30).floor()} months ago';
  }
}

class _JamendoSettingsCard extends ConsumerStatefulWidget {
  const _JamendoSettingsCard();

  @override
  ConsumerState<_JamendoSettingsCard> createState() =>
      _JamendoSettingsCardState();
}

class _JamendoSettingsCardState extends ConsumerState<_JamendoSettingsCard> {
  final _clientIdController = TextEditingController();
  bool _saving = false;
  bool _loadedInitialValue = false;

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedClientId = ref.watch(jamendoClientIdProvider);
    if (!_loadedInitialValue && savedClientId.hasValue) {
      _clientIdController.text = savedClientId.valueOrNull ?? '';
      _loadedInitialValue = true;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.public_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Jamendo catalog',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (savedClientId.valueOrNull?.isNotEmpty == true)
                  const Chip(
                    avatar: Icon(Icons.check_circle_outline, size: 17),
                    label: Text('CONNECTED'),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Register a free Jamendo developer application and paste its Client ID here. This identifier is public application metadata, not a password; requests go from your device to api.jamendo.com over HTTPS.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _clientIdController,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Jamendo Client ID',
                hintText: 'Paste your Client ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save Client ID'),
                ),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://devportal.jamendo.com/'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Jamendo developer portal'),
                ),
                if (_clientIdController.text.isNotEmpty)
                  TextButton(
                    onPressed: _saving ? null : _clear,
                    child: const Text('Disconnect'),
                  ),
              ],
            ),
            if (savedClientId.hasError) ...[
              const SizedBox(height: 8),
              Text(
                'Could not read saved provider settings.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final clientId = _clientIdController.text.trim();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a Jamendo Client ID first.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .putString(jamendoClientIdSettingKey, clientId);
      ref.invalidate(jamendoClientIdProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jamendo Client ID saved on this device.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the provider setting.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .remove(jamendoClientIdSettingKey);
      _clientIdController.clear();
      ref.invalidate(jamendoClientIdProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Jamendo disconnected.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove the provider setting.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
  });
  final IconData icon;
  final String title;
  final String description;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(description),
      ),
      trailing: Text(
        badge,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: .45),
      ),
    );
  }
}

class _AudioDeviceCard extends ConsumerWidget {
  const _AudioDeviceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final devices = ref.watch(audioOutputDevicesProvider).valueOrNull;
    final selected =
        ref.watch(selectedAudioOutputProvider).valueOrNull ??
        ref.watch(playbackControllerProvider).selectedAudioOutput;
    final decoded = ref.watch(decodedAudioFormatProvider).valueOrNull;
    final buffering = ref.watch(audioBufferingProvider).valueOrNull;
    final buffer = ref.watch(audioBufferPositionProvider).valueOrNull;
    final notice = ref.watch(playbackControllerProvider).audioDeviceNotice;
    final items = devices ?? const [];
    final selectedId = items.any((device) => device.id == selected.id)
        ? selected.id
        : items.any((device) => device.isAutomatic)
        ? 'auto'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speaker_group_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Output device',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'MEDIA-KIT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedId,
              decoration: const InputDecoration(
                labelText: 'Available system audio devices',
              ),
              items: [
                for (final device in items)
                  DropdownMenuItem(
                    value: device.id,
                    child: Text(
                      device.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: selectedId == null
                  ? null
                  : (id) {
                      if (id != null) {
                        ref
                            .read(playbackControllerProvider.notifier)
                            .selectOutputDevice(id);
                      }
                    },
            ),
            if (devices == null) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (selected.appearsBluetooth) ...[
              const SizedBox(height: 10),
              const _InlineNotice(
                icon: Icons.bluetooth_audio_rounded,
                text: 'Bluetooth audio may use codec-dependent compression and system-level processing. It is not bit-perfect.',
              ),
            ],
            if (notice != null) ...[
              const SizedBox(height: 10),
              _InlineNotice(icon: Icons.info_outline_rounded, text: notice),
            ],
            const Divider(height: 24),
            Text(
              'Decoder-reported PCM',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _StatusTile(
              icon: Icons.graphic_eq_rounded,
              title: decoded?.sampleFormat == null
                  ? 'Sample format unavailable'
                  : 'PCM ${decoded!.sampleFormat}',
              description:
                  '${_rate(decoded?.sampleRate)} · ${decoded?.channelLayout ?? _channels(decoded?.channelCount)} · ${buffering == true ? 'Buffering' : 'Not buffering'}${buffer == null ? '' : ' · ${buffer.inSeconds}s demux buffer'}',
              badge: buffering == true ? 'BUFFERING' : 'LIVE',
            ),
            const SizedBox(height: 8),
            Text(
              'Decoder PCM values describe the decoded stream, not the DAC hardware format. System output APIs may resample after this point; hardware bit depth, connection type, exclusive mode, and bit-perfect delivery are not exposed by this player backend.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static String _rate(int? sampleRate) => sampleRate == null
      ? 'Sample rate unknown'
      : '${(sampleRate / 1000).toStringAsFixed(sampleRate % 1000 == 0 ? 0 : 1)} kHz';

  static String _channels(int? count) => switch (count) {
    1 => 'Mono',
    2 => 'Stereo',
    null => 'Channel layout unknown',
    _ => '$count channels',
  };
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onTertiaryContainer, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioOutputModeCard extends StatelessWidget {
  const _AudioOutputModeCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Output mode',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                const Chip(label: Text('AUTOMATIC')),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Automatic is the only verified mode in the current media_kit/libmpv build.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                ChoiceChip(
                  label: Text('Automatic'),
                  selected: true,
                  onSelected: null,
                ),
                ChoiceChip(
                  label: Text('Standard · unavailable'),
                  selected: false,
                  onSelected: null,
                ),
                ChoiceChip(
                  label: Text('High Quality · unavailable'),
                  selected: false,
                  onSelected: null,
                ),
                ChoiceChip(
                  label: Text('Bit-Perfect / Direct · unavailable'),
                  selected: false,
                  onSelected: null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Automatic sends decoded audio to the system-managed output path. The OS or backend may resample or apply system processing. Exclusive output, hardware sample-rate verification, DAC hot-swap and bit-perfect delivery cannot be confirmed here; Cadence will not label this path Bit-Perfect.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/branding/cadence_icon.png',
                width: 68,
                height: 68,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ProductConfig.name,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Desktop preview · ${ProductConfig.version}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 26),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created by',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ProductConfig.creator,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Independent desktop implementation',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cadence is an independent local music player. Its library, tags, and playlists remain under your control on this computer.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.55),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acknowledgement',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Product concepts and design direction were informed by BitChord, an Android music player by Kushagra Singh (kushagrasinghx), licensed under GPL-3.0.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.55),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  ProductConfig.sourceReference,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  'The upstream Android/Kotlin source snapshot is included separately in third_party/BitChord under GPL-3.0. It is not linked into this Flutter app. This acknowledgement does not imply affiliation or endorsement.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
