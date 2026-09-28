# Build the macOS testing DMG

The project source can be built on a Mac with Flutter and Xcode installed. This creates an **unsigned, non-notarized** DMG for local testing; it is not a production distribution package.

1. Install Xcode from the Mac App Store, open it once, accept its license, and install the Xcode Command Line Tools. Install Flutter stable and confirm `flutter doctor` reports the macOS toolchain as available.
2. Extract `Cadence-online-music-app.zip` on the Mac.
3. In Terminal, run:

   ```sh
   cd /path/to/cadence_music
   ./tool/build_macos_dmg.sh
   ```

4. The script builds the release `.app` and writes `build/macos/Build/Products/Release/Cadence.dmg`. Open the DMG, then drag Cadence into Applications or copy it elsewhere for testing.

The first launch may be blocked because the app is not signed or notarized. For a local test, Control-click the app, choose **Open**, and confirm the macOS prompt. Do not use this unsigned build for public distribution. Public releases should be signed with the developer's Apple Developer ID and notarized using Apple's current distribution workflow.

Online Jamendo search additionally requires a Client ID; configure it in **Settings → Online music** after launching the app. See [online music source notes](ONLINE_MUSIC_SOURCE_NOTES.md) for provider limits and attribution behavior.
