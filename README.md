# Cadence

Cadence is a Flutter desktop music player for macOS, Windows, and Linux. It brings your **local music library** and an opt-in **Jamendo Creative Commons catalog** into one searchable player with a shared queue, playlists, lyrics lookup, and audio controls.

## Features

- Import and index local music folders; read tags and artwork through hAudiotagger.
- Search local files and, when configured, discover tracks in Jamendo's online catalog.
- Stream catalog results directly over HTTPS through Media Kit. Online tracks are not downloaded or added to the local-file database.
- Shared playback queue, shuffle/repeat, playlists, smart playlists, lyrics lookup, and a persistent local metadata database.
- Per-track artist/provider credit plus direct links to the Jamendo track page and its Creative Commons license.
- Responsive desktop shell, keyboard search/command shortcuts, Material 3 themes, and settings.

## Enable online catalog search

1. Register a non-commercial application in the [Jamendo developer portal](https://devportal.jamendo.com/) and obtain its **Client ID**.
2. Open **Settings → Online music**, paste the Client ID, and save it.
3. Open **Search → Online catalog**, then search by track, album, artist, or tags.

The Client ID is public application metadata and is stored in Cadence's local SQLite settings. Search terms go directly from your device to Jamendo's API. Cadence streams the API's `audio` URL; it does not use the API download URL. Jamendo's current API terms limit free API access to non-commercial use, require creator/provider credit and links to each track, and require each track to be used according to its Creative Commons license. Review a track's license before reusing its content. Commercial or monetized use needs permission from Jamendo.

## Provider boundaries

This release does **not** extract audio streams from YouTube/YouTube Music or Spotify, or use unofficial provider APIs. YouTube's official API policies prohibit separating audio from audiovisual content and background-player behavior; its official player must remain intact. Spotify's official in-app streaming route is the Web Playback SDK, requires Premium, and its developer terms restrict commercial use without prior approval. Those services need their approved playback experiences and credentials, so they are not presented as connected providers here.

## BitChord source copy

The complete **543-file tracked BitChord source snapshot** requested for reference is included separately at [`third_party/BitChord`](third_party/BitChord). To avoid republishing an upstream embedded credential, its `GOOGLE_API_KEY` value in `app/src/main/java/com/music/bitchord/data/innertube/potoken/PoTokenWebView.kt` has been replaced with `REDACTED_FOR_PUBLIC_REPOSITORY`; all 543 files and the upstream GPL-3.0 license remain present. This Android/Kotlin source is **not compiled, linked, or used as a Flutter dependency**. See [`third_party/README.md`](third_party/README.md), [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md), and the upstream [`LICENSE`](third_party/BitChord/LICENSE).

## Build and test

Use Flutter stable with Dart 3.13.4 or newer:

```sh
flutter pub get
flutter analyze
flutter test
```

On a Mac with Xcode, run `./tool/build_macos_dmg.sh` to create an unsigned local-testing DMG at `build/macos/Build/Products/Release/Cadence.dmg`; see [`docs/BUILD_MACOS.md`](docs/BUILD_MACOS.md). Public macOS distribution needs Apple Developer ID signing and notarization. Windows builds require Windows/Visual Studio; Linux development builds require Flutter's Linux desktop toolchain and GTK development libraries.

See [`ONLINE_MUSIC_SOURCE_NOTES.md`](docs/ONLINE_MUSIC_SOURCE_NOTES.md) for provider-policy details, plus [`PROJECT_STATUS.md`](PROJECT_STATUS.md), [`ARCHITECTURE.md`](ARCHITECTURE.md), and [`BRANDING.md`](BRANDING.md). The product name and bundle identifier are provisional.

## References

- [BitChord by Kushagra Singh](https://github.com/kushagrasinghx/BitChord) — copied source snapshot is GPL-3.0.
- [Jamendo API documentation](https://developer.jamendo.com/v3.0/docs) and [API Terms of Use](https://devportal.jamendo.com/api_terms_of_use).
- [YouTube API Developer Policies](https://developers.google.com/youtube/terms/developer-policies).
- [Spotify Web Playback SDK](https://developer.spotify.com/documentation/web-playback-sdk) and [Spotify Developer Terms](https://developer.spotify.com/terms).
