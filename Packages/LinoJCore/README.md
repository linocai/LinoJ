# LinoJCore

Shared Swift package powering both LinoJ apps (`LinoJ-macOS` and `LinoJ-iOS`).
It holds the data models, persistence, view models, services, design system,
and localization — everything platform-agnostic. The two App targets contain
only platform-specific SwiftUI views and depend on this package.

## Open in Xcode

Open the workspace at the repository root, not this package directly:

```sh
open LinoJ.xcworkspace
```

The workspace contains both App projects and references this package by path.
Editing files here updates both apps. Minimum deployment: macOS 26 / iOS 26,
Swift 6 (strict concurrency).

## Run the tests

This package's tests are pure unit tests (no UI). Run them from the repo root
without Xcode:

```sh
swift test --package-path Packages/LinoJCore
```

With line-coverage instrumentation:

```sh
swift test --package-path Packages/LinoJCore --enable-code-coverage
```

You can also run them inside Xcode via the `LinoJCore` scheme (Product → Test).

## Module layout

```
Sources/LinoJCore/
├── Models/         @Model types (Todo, Project, Event, Person) + enums
├── Persistence/    ModelContainer factory + DEBUG seed data
├── ViewModels/     @Observable @MainActor screen view models
├── Services/       HeadsUp / Notification / YesterdayMissed / AppServices
├── Auth/           Sign in with Apple state machine + Keychain store
├── CloudKit/       CloudSyncMonitor + remote-notification registrar
├── Navigation/     TabRouter
├── DesignSystem/   Colors / Typography / Spacing / Radii / Modifiers / Components
├── Localization/   Localizable.xcstrings (zh + en) + compiled .lproj
├── Time/           LinoJTime clock abstraction
└── Platform/       Haptics + platform shims

Tests/LinoJCoreTests/   Unit tests mirroring the above
```

> The authoritative product spec and full phase plan live in the repo-root
> `PROJECT_PLAN.md`; this README only covers building and testing the package.
