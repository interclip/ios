# Interclip for iOS

The native iOS client for [Interclip](https://interclip.app) — share short links and files between devices.

Send any URL or file from your iPhone or iPad and get back a short clip code that anyone can paste into Interclip on the web (or another device) to retrieve the original.

## Features

- **Send** — Turn any URL into a short clip code.
- **Files** — Upload files and share the resulting clip.
- **Receive** — Look up a clip code to retrieve the original URL or file.
- **Share extension** — Share into Interclip from any other app.
- **App Intents** — Create and look up clips from Shortcuts and Spotlight.

## Screenshots

| Send | Files | Receive | Settings |
| :--: | :---: | :-----: | :------: |
| ![Send](docs/screenshots/01_Send_framed.png) | ![Files](docs/screenshots/02_Files_framed.png) | ![Receive](docs/screenshots/03_Receive_framed.png) | ![Settings](docs/screenshots/04_Settings_framed.png) |

Captured on iPhone 16 Pro, framed with Apple device bezels via [`viticci/frames-cli`](https://github.com/viticci/frames-cli).
Regenerated automatically by the [Screenshots workflow](.github/workflows/screenshots.yml) whenever the UI changes.

## Requirements

- iOS 18.0 or later
- Xcode 16 or later
- Ruby 3.3+ with Bundler (for fastlane)

## Building

Open the project in Xcode and run the `Interclip` scheme on a simulator or device:

```sh
open Interclip.xcodeproj
```

## Tests

Unit tests:

```sh
xcodebuild test \
  -project Interclip.xcodeproj \
  -scheme Interclip \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Regenerating screenshots

Screenshots are produced by the `InterclipUITests/testScreenshots` UI test and captured with [fastlane snapshot](https://docs.fastlane.tools/actions/snapshot/). Configuration lives in [`fastlane/Snapfile`](fastlane/Snapfile).

Locally:

```sh
bundle install
bundle exec fastlane snapshot
```

Output is written to `fastlane/screenshots/`. To produce framed versions used in this README, install [`frames-cli`](https://github.com/viticci/frames-cli) and run:

```sh
frames -o docs/screenshots fastlane/screenshots/en-US/iPhone\ 16\ Pro-*.png
```

In CI, the [Screenshots workflow](.github/workflows/screenshots.yml) does both of these on every push to `main` that touches the UI, and commits any visual diffs back to `docs/screenshots/`.

