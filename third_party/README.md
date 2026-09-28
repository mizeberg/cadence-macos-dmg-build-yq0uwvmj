# Third-party source snapshots

## BitChord

`BitChord/` contains all 543 tracked files from <https://github.com/kushagrasinghx/BitChord> at commit `fe198ac0bde052f8b84cfd84b1d271f8f1fcc7b2`. The upstream `GOOGLE_API_KEY` value in `app/src/main/java/com/music/bitchord/data/innertube/potoken/PoTokenWebView.kt` is replaced with `REDACTED_FOR_PUBLIC_REPOSITORY` in this public copy; no tracked files are omitted. The original `LICENSE`, notices, and other files are retained. BitChord is GPL-3.0 licensed; consult `BitChord/LICENSE` before redistributing this snapshot.

This is a separate Android/Kotlin project included for reference. Cadence is a Flutter desktop application and does not compile, link, or load the BitChord project. The user-facing Cadence implementation uses the Flutter app in the supplied archive and the official Jamendo API; it does not port BitChord's YouTube stream extraction.
