# CleanerVar

A SwiftUI iOS cache utility with a dark red/green dashboard.

## Safety and iOS limitations

CleanerVar uses only public Foundation file APIs and only accesses its **own** sandbox:

- `Library/Caches`
- the app's temporary (`tmp`) directory

It does not enumerate, read, or delete another app's container. It does not use the `worse_query` sandbox-escape proof of concept. Standard iOS apps cannot silently clear other apps' private caches; users can manage those apps through iOS Settings or the app's own controls.

Documents, preferences, Keychain items, databases and sign-in state are not targeted.

## Project settings

- Display name: `CleanerVar`
- Bundle identifier: `com.milanvu.cleanervar`
- Deployment target: iOS 27.0
- UI: SwiftUI

## Build on GitHub Actions

1. Create a GitHub repository and upload/push the contents of this folder.
2. Open **Actions** and enable workflows if GitHub asks.
3. Run **Build CleanerVar IPA** with **Run workflow**, or push a tag such as `v1.0.0`.
4. Download `CleanerVar-unsigned.ipa` from the workflow's Artifacts section. A tag build also attaches it to a GitHub Release.

### Important: signing

The workflow intentionally creates an **unsigned** IPA. It is a build artifact, not directly installable on a normal iPhone. To install it, sign it with a valid Apple Development/Ad Hoc certificate and a provisioning profile that includes the target device (or use an appropriate distribution method). Do not commit `.p12`, `.mobileprovision`, passwords, or signing keys to the repository. A separate signing job can be added using GitHub Actions encrypted secrets.

## Local build

Open `CleanerVar.xcodeproj` in a compatible Xcode release with the iOS 27 SDK, select the `CleanerVar` scheme, choose a physical iPhone destination, and build. A signed installable IPA requires valid signing assets.
