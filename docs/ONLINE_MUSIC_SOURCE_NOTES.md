# Online music sources: implementation notes

Checked: 2026-09-28. This is engineering context, not legal advice; re-check provider terms before distributing or monetizing Cadence.

## Jamendo

- API reference: <https://developer.jamendo.com/v3.0/docs> and [tracks method](https://developer.jamendo.com/v3.0/tracks).
- API Terms of Use: <https://devportal.jamendo.com/api_terms_of_use>.
- The tracks API distinguishes the `audio` stream URL from `audiodownload`, and returns license information when `include=licenses` is requested. The app uses only `audio`, requests license details, and requires an HTTPS stream URL.
- Terms clause 3.1 requires use to respect the Creative Commons license attached to each content item. Clause 3.3 says free API access is for non-commercial use; commercial use includes monetary compensation and revenue from advertising or affiliate programs. It also prohibits designing applications to cache content or offer offline access, apart from caching reasonably necessary for normal app operation.
- Terms clause 4.1 requires crediting the Jamendo member as creator, Jamendo as the content provider, and a direct backlink from each content item to its Jamendo page. Cadence shows creator and provider in each result row and exposes a visible direct track-page button plus the license link.
- Terms clause 4.2 prohibits branding that implies the app is official or endorsed by Jamendo. Cadence is branded as Cadence and does not use Jamendo branding as its identity.

## YouTube and Spotify

- [YouTube API Services Developer Policies](https://developers.google.com/youtube/terms/developer-policies) constrain how audiovisual content may be played; Cadence does not extract audio or run a hidden/background YouTube player. An official YouTube playback experience would need to keep the approved player intact and visible.
- [Spotify Web Playback SDK documentation](https://developer.spotify.com/documentation/web-playback-sdk) and [Spotify Developer Terms](https://developer.spotify.com/terms) describe the supported web playback route and its account/usage restrictions. Cadence does not expose Spotify catalog playback without an approved SDK flow and required user/provider configuration.

## Product setup and data path

Jamendo online search is optional. The user registers a non-commercial Jamendo developer application and saves its public Client ID in local Cadence settings. Search requests go from the app directly to `api.jamendo.com` over HTTPS. Audio and artwork come from the returned URLs; online songs remain transient playback-queue entries, are not inserted into the local-file library or local play-history table, and are not downloaded for offline use.
