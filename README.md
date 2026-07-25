# Orbit Family

A native SwiftUI iOS + watchOS demo of local Bonjour discovery and pairing.

## Demo flow

1. On the parent iPhone, choose **Start onboarding**, finish the whimsical intro, and tap **Add child**.
2. On another iPhone, choose **I’m a child — find my parent** from the welcome screen.
3. Or on Apple Watch, choose **I’m a child**.
4. For iPhone-to-iPhone pairing, allow local-network access. Keep both apps open and the devices close together for the optional distance check.
5. Select the child on the parent iPhone and assign a color.
6. The child device immediately adopts that color. A child can use **Log out** to return to the role/login screen.

## Architecture

- SwiftUI with persisted role/color state through `@AppStorage`
- `NWListener` advertises `_orbitparent._tcp` from the parent iPhone
- `NWBrowser` on a child iPhone discovers and connects to the parent
- `NWConnection` transfers newline-delimited Codable messages over the local network
- `WatchConnectivity` exchanges pairing state and color assignments with this iPhone’s paired Apple Watch
- `NISession` optionally confirms physical proximity after the devices exchange discovery tokens over the active transport
- Devices without Nearby Interaction support continue over their active Bonjour or WatchConnectivity transport
- No cloud service, account backend, or internet connection is used

## Open and run

Open `ConceptsOnboarding.xcodeproj` after generating it with:

```sh
xcodegen generate
```

Install the `ConceptsOnboarding` iPhone app first; it embeds the companion Watch app. Then run `OrbitFamilyWatch` on the Apple Watch if Xcode did not install it automatically. Bonjour is best exercised on physical iPhones; simulators may not mirror all local-network permission and multicast behavior.

Before installing on physical devices, choose the same Apple Developer team under **Signing & Capabilities** for both app targets. WatchConnectivity works only between an iPhone and its paired Apple Watch; watchOS does not permit a general-purpose app to open the low-level TCP connection behind arbitrary Bonjour results.

## Diagnostics

Each app has a normal scheme and a diagnostics scheme:

- `ConceptsOnboarding` / `ConceptsOnboarding Diagnostics`
- `OrbitFamilyWatch` / `OrbitFamilyWatch Diagnostics`

The diagnostics schemes set `ORBIT_DIAGNOSTICS_ENABLED=1` in the Run, Test, and Profile environment. The normal schemes set it to `0`. When the flag is disabled, the app does not collect or emit pairing diagnostics and the diagnostics panels are hidden.
