fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios development

```sh
[bundle exec] fastlane ios development
```

Push a new iOS development build

### ios production

```sh
[bundle exec] fastlane ios production
```

Push a new iOS production build

### ios frame_screenshots

```sh
[bundle exec] fastlane ios frame_screenshots
```

Resize and frame raw screenshots locally with custom titles and background colors

### ios export_appstore_screenshots

```sh
[bundle exec] fastlane ios export_appstore_screenshots
```

Export App Store Connect-ready iPhone screenshots (default 1284x2778 for 6.5 inch display, no alpha)

### ios export_appstore_ipad_screenshots

```sh
[bundle exec] fastlane ios export_appstore_ipad_screenshots
```

Export App Store Connect-ready 13 inch iPad screenshots (default 2048x2732, no alpha)

### ios export_appstore_preview

```sh
[bundle exec] fastlane ios export_appstore_preview
```

Convert a simulator recording into a 6.9 inch App Store app preview (886x1920, H.264)

### ios export_appstore_assets

```sh
[bundle exec] fastlane ios export_appstore_assets
```

Export App Store screenshots and optionally an app preview video

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
