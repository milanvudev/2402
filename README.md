# CleanerVar

Responsive SwiftUI storage utility for iOS.

## Scope and iOS privacy boundary

On a standard, non-jailbroken iPhone, an app cannot enumerate or remove another app's private cache. CleanerVar therefore scans and cleans only its own `Library/Caches` and temporary directory using public Foundation APIs. It does not use sandbox-escape exploits or claim to clean other apps.

For system-wide per-app storage management, use **Settings → General → iPhone Storage**. A third-party app cannot automate that screen or delete those private containers.

## Build

Open `CleanerVar/CleanerVar.xcodeproj` in Xcode and build the `CleanerVar` scheme.

GitHub Actions workflow: `.github/workflows/build-ipa.yml`.
The workflow produces an **unsigned** IPA artifact. Sign it with an appropriate Apple Development/Distribution certificate and provisioning profile before installing it on a physical iPhone.

Minimum deployment target: iOS 17.0. The workflow uses the iOS SDK installed on the GitHub macOS runner; it does not require an iOS 27 SDK.
