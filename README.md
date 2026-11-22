# BrassTune iOS

BrassTune is an iPhone and iPad practice companion for brass musicians. It includes live pitch feedback, tuning and reference tones, metronome and drone practice, guided exercises, practice-history analytics, and optional account features.

Project attribution: Arya Salem

## Open and test

This repository keeps its Swift paths intentionally intact:

- Open `swift/BrassTuneApp/BrassTuneApp.xcodeproj` in Xcode.
- The app requires Swift 6 and has an iOS 17 deployment target.
- `BrassTuneCore` is a local Swift package at `swift/BrassTuneCore`, referenced by the app project as a sibling directory.
- Run the shared domain tests from the repository root with `cd swift/BrassTuneCore && swift test`.

The test suites load the shared JSON fixtures from the root `fixtures/` directory, so retain this layout when cloning or copying the project.

## Configuration and signing

Choose your own Apple signing team and bundle identifiers before building on a device. The project contains no Apple signing certificates, provisioning profiles, secret keys, service-role credentials, recordings, local databases, or user data.

The account-capable build expects a public API origin plus public Supabase URL and publishable key. See `swift/BrassTuneApp/CONFIGURATION.md`. Do not add service-role keys, database passwords, or any other secret to the project. The archive helper requires valid public account configuration; use your own service endpoints when maintaining a fork.

`scripts/ios/build-testflight.sh` is an owner-operated archive/export helper. It requires your own Apple Developer configuration, registered bundle identifier, and public runtime configuration; it does not upload an app by itself.

## Third-party notices and license

`swift/BrassTuneApp/BrassTuneApp/Resources/Fonts/GoogleSans-Medium.ttf` is distributed with its required SIL Open Font License 1.1 text in the same directory.

No license grant for the BrassTune application source is provided by this repository. Contact the project owners for reuse permissions.
