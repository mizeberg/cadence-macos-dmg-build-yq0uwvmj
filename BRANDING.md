# Branding configuration

The provisional name **Cadence** and product URLs live in `lib/core/config/product_config.dart`. The macOS bundle identifier, title, icon catalog, and copyright are configured in `macos/Runner/Configs/AppInfo.xcconfig` and the icon asset catalog. Windows name/version metadata and icon are configured in `windows/runner/Runner.rc`, `windows/runner/main.cpp`, and `windows/runner/resources/app_icon.ico`.

Before any public release, finalize the app name, reverse-DNS bundle identifier, support/website URLs, copyright line, and signing identity, then update the centralized Dart configuration and native runner metadata together. The name and bundle identifier in this scaffold are provisional.
