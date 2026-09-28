# Architecture

Cadence is a Flutter desktop music player organized feature-first. UI widgets render state and dispatch intent; domain rules belong in application/domain services, with persistence, audio, network, and platform details behind adapters. Riverpod provides dependency injection and feature state.

## Core boundaries

- `core/config/`, `core/theme/`, and `core/widgets/` own product identity, design tokens, and reusable presentation primitives.
- `core/database/` owns the local SQLite database and repositories for library data and settings.
- `features/library/` owns indexed local-file entities, metadata extraction, artwork, and search.
- `features/playback/` owns playback state/queue rules and the Media Kit adapter. A track is opened using its local file path or an explicitly provider-returned HTTPS audio URL.
- `features/online/` owns the Jamendo API client, result mapping, local Client ID setting, and provider search state. The adapter uses the official `/v3.0/tracks/` API, requests license data, and uses only the API's `audio` stream URL—not its download URL.
- `features/playlists/`, `features/search/`, `features/settings/`, and `features/shell/` own their UI flows.

Jamendo catalog results exist transiently in the playback queue and are not inserted into SQLite's local-song table or playback-history relation. Their source and license links remain attached to the transient song model so the UI can provide creator/provider attribution. Requests use HTTPS directly from the user's device; no credentials or provider streams are proxied through a Cadence server.

The app intentionally does not extract provider media from undocumented endpoints, download/copy Jamendo audio for offline use, or strip audio from YouTube videos. Any new network source must have an official, terms-compliant playback path and preserve provider attribution and each track's license.

## Third-party source snapshot

`third_party/BitChord/` contains the separate upstream Android/Kotlin GPL-3.0 source snapshot requested by the user. It is retained for reference, is not compiled or linked into the Flutter application, and is not a provider implementation for Cadence.
