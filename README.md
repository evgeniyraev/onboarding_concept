# Orbit Family

A native SwiftUI iOS + watchOS demo of local Bonjour discovery and pairing.

## Demo flow

1. On the parent iPhone, choose **Start onboarding**, finish the whimsical intro, and tap **Add child**.
2. On another iPhone, choose **I’m a child — find my parent** from the welcome screen.
3. Or on Apple Watch, choose **I’m a child**.
4. Allow local-network access on each child device. Keep both apps open and the devices close together for the optional distance check.
5. Select the child on the parent iPhone and assign a color.
6. The child device immediately adopts that color. A child can use **Log out** to return to the role/login screen.

## Architecture

- SwiftUI with persisted role/color state through `@AppStorage`
- `NWListener` advertises `_orbitparent._tcp` from the parent iPhone
- `NWBrowser` on a child iPhone or Apple Watch discovers and connects to the parent
- `NWConnection` transfers newline-delimited Codable messages over the local network
- The local-network path does not require the child Watch and parent iPhone to use the same Apple ID
- `WatchConnectivity` remains available as a fallback for this iPhone’s paired Apple Watch
- `NISession` optionally confirms physical proximity after the devices exchange discovery tokens over the active transport
- Devices without Nearby Interaction support continue over their active Bonjour or WatchConnectivity transport
- No cloud service, account backend, or internet connection is used

Nearby Interaction and diagnostics are controlled for both apps in
`Config/FeatureFlags.xcconfig`:

- `ORBIT_NEARBY_INTERACTION_ENABLED` controls ranging and token exchange.
- `ORBIT_DIAGNOSTICS_ENABLED` controls diagnostic logging and panels.

Both flags default to `NO`. Change a value and rebuild to apply it; Bonjour and
WatchConnectivity pairing remain available when Nearby Interaction is disabled.

## Open and run

Open `ConceptsOnboarding.xcodeproj` after generating it with:

```sh
xcodegen generate
```

Install the `ConceptsOnboarding` iPhone app first; it embeds the companion Watch app. Then run `OrbitFamilyWatch` on the Apple Watch if Xcode did not install it automatically. Bonjour is best exercised on physical iPhones; simulators may not mirror all local-network permission and multicast behavior.

Before installing on physical devices, choose the same Apple Developer team under **Signing & Capabilities** for both app targets. The parent iPhone and child Watch can use different Apple IDs, but both apps must be open with local-network access while pairing.

## Diagnostics

Each app has a normal scheme and a diagnostics scheme:

- `ConceptsOnboarding` / `ConceptsOnboarding Diagnostics`
- `OrbitFamilyWatch` / `OrbitFamilyWatch Diagnostics`

The diagnostics schemes override `ORBIT_DIAGNOSTICS_ENABLED` to `1` in the Run,
Test, and Profile environment. Normal schemes use the value from
`Config/FeatureFlags.xcconfig`. When the flag is disabled, the app does not
collect or emit pairing diagnostics and the diagnostics panels are hidden.
