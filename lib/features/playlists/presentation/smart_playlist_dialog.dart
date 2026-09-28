import 'package:flutter/material.dart';

import '../domain/smart_playlist_rule.dart';

class SmartPlaylistDraft {
  const SmartPlaylistDraft({required this.rule, this.title});
  final String? title;
  final SmartPlaylistRule rule;
}

Future<SmartPlaylistDraft?> showSmartPlaylistDialog(
  BuildContext context, {
  String? initialTitle,
  SmartPlaylistRule initialRule = const SmartPlaylistRule(),
}) async {
  final titleController = TextEditingController(text: initialTitle ?? '');
  final genreController = TextEditingController(text: initialRule.genre ?? '');
  var favorites = initialRule.favoritesOnly;
  var lossless = initialRule.losslessOnly;
  var rating = initialRule.minimumRating ?? 0;
  var plays = initialRule.minimumPlayCount ?? 0;
  var days = initialRule.addedWithinDays ?? 0;
  var sort = initialRule.sort;
  try {
    return await showDialog<SmartPlaylistDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(initialTitle == null ? 'Create smart playlist' : 'Edit smart playlist rules'),
          content: SizedBox(
            width: 480,
            height: 510,
            child: ListView(
              children: [
                if (initialTitle == null) ...[
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Playlist name'),
                  ),
                  const SizedBox(height: 8),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Favorites only'),
                  value: favorites,
                  onChanged: (value) => setState(() => favorites = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lossless sources only'),
                  value: lossless,
                  onChanged: (value) => setState(() => lossless = value),
                ),
                DropdownButtonFormField<int>(
                  initialValue: rating,
                  decoration: const InputDecoration(labelText: 'Minimum star rating'),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('Any rating')),
                    for (var stars = 1; stars <= 5; stars++)
                      DropdownMenuItem(value: stars, child: Text('$stars stars or higher')),
                  ],
                  onChanged: (value) => setState(() => rating = value ?? 0),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: plays,
                  decoration: const InputDecoration(labelText: 'Minimum play count'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Any play count')),
                    DropdownMenuItem(value: 1, child: Text('Played at least once')),
                    DropdownMenuItem(value: 5, child: Text('Played at least 5 times')),
                    DropdownMenuItem(value: 20, child: Text('Played at least 20 times')),
                  ],
                  onChanged: (value) => setState(() => plays = value ?? 0),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: days,
                  decoration: const InputDecoration(labelText: 'Added within'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Any time')),
                    DropdownMenuItem(value: 7, child: Text('7 days')),
                    DropdownMenuItem(value: 30, child: Text('30 days')),
                    DropdownMenuItem(value: 90, child: Text('90 days')),
                    DropdownMenuItem(value: 365, child: Text('1 year')),
                  ],
                  onChanged: (value) => setState(() => days = value ?? 0),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: genreController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Genre (optional)',
                    hintText: 'Exact genre match',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<SmartPlaylistSort>(
                  initialValue: sort,
                  decoration: const InputDecoration(labelText: 'Sort results by'),
                  items: const [
                    DropdownMenuItem(value: SmartPlaylistSort.recentlyAdded, child: Text('Recently added')),
                    DropdownMenuItem(value: SmartPlaylistSort.mostPlayed, child: Text('Most played')),
                    DropdownMenuItem(value: SmartPlaylistSort.highestRated, child: Text('Highest rated')),
                    DropdownMenuItem(value: SmartPlaylistSort.title, child: Text('Title')),
                  ],
                  onChanged: (value) => setState(() => sort = value ?? SmartPlaylistSort.recentlyAdded),
                ),
                const SizedBox(height: 10),
                const Text('Rules are combined with AND. Results update as your local library and listening history change.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = initialTitle ?? titleController.text.trim();
                if (initialTitle == null && name.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  SmartPlaylistDraft(
                    title: initialTitle == null ? name : null,
                    rule: SmartPlaylistRule(
                      favoritesOnly: favorites,
                      losslessOnly: lossless,
                      minimumRating: rating == 0 ? null : rating,
                      minimumPlayCount: plays == 0 ? null : plays,
                      addedWithinDays: days == 0 ? null : days,
                      genre: genreController.text.trim().isEmpty ? null : genreController.text.trim(),
                      sort: sort,
                    ),
                  ),
                );
              },
              child: Text(initialTitle == null ? 'Create' : 'Save rules'),
            ),
          ],
        ),
      ),
    );
  } finally {
    titleController.dispose();
    genreController.dispose();
  }
}
