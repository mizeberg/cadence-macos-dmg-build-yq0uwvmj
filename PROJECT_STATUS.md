# Project Status — Cadence

Last updated: 2026-09-28

## Current phase

Local library/playback is in place; this continuation adds an opt-in online discovery and streaming source aligned with Jamendo's documented API constraints.

## Implemented

- Local library folder and file import, incremental scanning, metadata/artwork extraction, and SQLite-backed library/search/favorite history.
- Material 3 library, search, playlists, queue, now-playing, and audio-information views wired to Riverpod state.
- Media Kit playback adapter, queue/shuffle/repeat, playlists, smart playlist rules, lyrics lookup, durable appearance settings, and window bounds.
- Jamendo HTTPS catalog search, debounced query requests, direct audio streaming through the existing playback queue, remote artwork, per-track creator/provider attribution, direct track and CC-license links, and a local Client ID setting.
- Online tracks remain transient queue entries; they are not inserted into the local file library, downloaded, or counted in local file history.
- BitChord's complete tracked file set (543 files at commit `fe198ac0bde052f8b84cfd84b1d271f8f1fcc7b2`) copied into `third_party/BitChord` with its GPL-3.0 license. The upstream `GOOGLE_API_KEY` value in `PoTokenWebView.kt` is replaced with a placeholder for this public build repository; no files were omitted. It is a separate Android/Kotlin source project, not a Cadence dependency.
- Tests cover schema/repository behavior, incremental indexing, queue behavior, lyrics, playback controller behavior, widgets, and Jamendo track/API parsing.

## Provider and licensing limits

- Jamendo's current API terms permit free non-commercial use, require provider/artist attribution and a direct track-page backlink, and require respecting each track's Creative Commons license. Search requires the user to configure a Client ID. Check provider terms again before any release; monetized/commercial use needs Jamendo permission.
- YouTube/YouTube Music raw audio extraction and Spotify streaming are not integrated. This build avoids undocumented or policy-incompatible extraction and uses no downloaded provider tracks.
- No Jamendo Client ID is bundled; online search stays disconnected until the user configures one.

## Verification and platform limits

- Verified with Flutter 3.47.5 stable and Dart 3.13.4: `flutter analyze` reports no issues, and all 30 tests pass. Dependencies and the lockfile were refreshed.
- A Linux desktop binary was not built because this sandbox lacks GTK development headers. macOS and Windows builds require their respective host operating systems and toolchains.
- Bit-perfect/direct-output claims remain backend/platform dependent; the UI reports decoder information without guaranteeing DAC behavior.
- Package-license notices should be regenerated after dependency resolution with `python3 tool/generate_third_party_notices.py`.
