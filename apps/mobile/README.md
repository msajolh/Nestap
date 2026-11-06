# Nestap mobile app (Flutter)

The Nestap smart home app for Android and iOS (it also runs on tablets and desktop). It is built with **Clean Architecture**, **Riverpod 3** for state, **GoRouter** for navigation, and a **responsive** layout with Material 3 window size classes. Colors and type come from the Nestap logo and [nestap.net](https://nestap.net).

## Run it

1. Install Flutter (3.35 or newer).
2. Platform folders (`android/`, `ios/`) are not committed yet. Generate them once:

   ```bash
   cd apps/mobile
   flutter create . --project-name nestap --org net.nestap --platforms android,ios
   ```

   `flutter create` only adds missing files; it does not overwrite `lib/` or `test/`. Then set Android `minSdk` to **23** in `android/app/build.gradle.kts` (needed by `flutter_secure_storage` and the Tuya SDK).
3. Start in **demo mode** (no server needed: in-memory home with Nalite-style switches, a socket, a curtain, a light and scenes):

   ```bash
   flutter pub get
   flutter run
   ```

   Sign in with any email and any 6-digit code.
4. Against a real Nestap cloud:

   ```bash
   flutter run --dart-define=NESTAP_API_URL=https://api.ap-southeast.nestap.io --dart-define=NESTAP_RT_URL=wss://rt.ap-southeast.nestap.io/v1/stream
   ```

Tests: `flutter test`.

## Architecture

```
lib/
├── main.dart · bootstrap.dart · app.dart     start-up, ProviderScope, MaterialApp.router
├── core/                                     shared by every feature, no feature imports
│   ├── config/        AppConfig (--dart-define)
│   ├── error/         Failure types (the only errors the UI sees)
│   ├── network/       ApiClient (Dio), AuthInterceptor (token + refresh), error mapping
│   ├── storage/       TokenStore (Keychain / Keystore)
│   ├── realtime/      RealtimeClient (WebSocket), RealtimeEvent
│   ├── dev/           Demo backend: answers the real API contract in memory
│   ├── router/        GoRouter, auth redirect, Routes
│   ├── theme/         AppColors, AppTheme (light/dark), spacing
│   ├── responsive/    WindowSize, breakpoints, ResponsiveCenter
│   ├── widgets/       AppShell, NestapLogo, AsyncValueView, MessageView
│   └── providers.dart infrastructure providers (Dio, storage, realtime)
└── features/
    ├── auth/          OTP sign-in, session restore, sign-out
    ├── home/          homes, rooms, dashboard
    ├── devices/       device model, live state, commands, detail controls
    ├── pairing/       add device (Tuya SDK bridge → import into Nestap)
    ├── scenes/        tap-to-run scenes, automation on/off
    ├── profile/       account page
    └── settings/      theme mode
```

Each feature has the same layers:

```
features/<feature>/
├── domain/          pure Dart: entities, repository interfaces, use cases
├── data/            DTOs, remote data sources, repository implementations
├── presentation/    providers (Notifiers), pages, widgets
└── <feature>_providers.dart   wiring: data → domain (the feature's composition root)
```

**Dependency rule:** `presentation → domain ← data`.
- `domain` imports nothing from Flutter, Dio or Riverpod.
- `data` implements the `domain` interfaces and converts every transport error to a `Failure`.
- `presentation` talks to use cases and repository interfaces through providers, never to Dio.

Use cases exist where there is a business rule: validating sign-in input, sorting devices, refusing commands to offline devices. Thin features (scenes) call their repository interface directly. A use case that only passes a call through adds code without adding safety.

### State management (Riverpod 3, no code generation)

| Kind | Used for | Example |
|------|----------|---------|
| `Provider` | Dependencies, derived values | `apiClientProvider`, `visibleDevicesProvider` |
| `FutureProvider` | Read-only async data | `homesProvider`, `roomsProvider` |
| `Notifier` | Synchronous app state | `authControllerProvider`, `themeModeProvider`, `selectedRoomIdProvider` |
| `AsyncNotifier` | Async state with actions | `homeDevicesProvider` (optimistic commands + realtime), `rulesProvider` |

- Live device state: `HomeDevicesController` loads the home's devices, subscribes to the realtime gateway, and applies `state` events only when their shadow `version` is newer. Commands update the UI at once and roll back only the changed keys if the cloud rejects them.
- Start-up values that need `await` (SharedPreferences) are loaded in `bootstrap.dart` and injected with `overrideWithValue`, so providers stay synchronous.

### Navigation (GoRouter)

| Path | Page | Notes |
|------|------|-------|
| `/splash` | Splash | Shown while the stored session is checked |
| `/sign-in` | Sign in | Email/phone → 6-digit code |
| `/home` | Dashboard | Tab 1 |
| `/home/devices/:id` | Device detail | Pushed inside tab 1 |
| `/home/add-device` | Add device | Pushed inside tab 1 |
| `/scenes` | Scenes and automations | Tab 2 |
| `/profile` | Me | Tab 3 |

The tabs use `StatefulShellRoute.indexedStack`, so each tab keeps its own back stack. The `redirect` depends only on `AuthState`: unknown → splash, signed out → sign-in, signed in → away from both. The router listens to `authControllerProvider`, so session expiry anywhere sends the user to sign-in.

### Responsive layout

| Window | Width | Navigation | Layout |
|--------|-------|------------|--------|
| Compact | < 600 | Bottom `NavigationBar` + FAB | Single column, sign-in stacked |
| Medium | 600–1023 | `NavigationRail` with labels | Device grid widens, sign-in split |
| Expanded | ≥ 1024 | Extended rail with logo | Content capped at 1200 px and centered |

Device grids use `SliverGridDelegateWithMaxCrossAxisExtent`, so the number of columns follows the width. Gang buttons on a switch go 2 → 4 across on wide screens.

### Theme

| Token | Value | Use |
|-------|-------|-----|
| `brand` | `#43C6DB` | Logo, stats, focus ring |
| `cyan400` | `#00D3F3` | Main buttons (with navy text, like nestap.net), "on" state |
| `cyan700` | `#007595` | Primary text/icons on white (meets WCAG contrast) |
| `navy` | `#101828` | Text, dark surfaces, hero panels |
| `ink` | `#030712` | Dark-mode background |
| `slate` / `gray300` | `#4A5565` / `#D1D5DC` | Secondary text / borders |
| Font | Lato | Same as nestap.net. Bundle it in `assets/fonts` before release, so it doesn't download at first launch |

Buttons are pill-shaped and cards have 20 px corners. Light and dark themes are both complete, and the user can choose either or follow the system (Me → Appearance).

## Tuya pairing (Phase 1 devices)

Pairing follows [06-device-compatibility.md](../../docs/architecture/06-device-compatibility.md) §3.3:

1. `POST /v1/connectors/tuya/session` gets the hidden Tuya identity.
2. **Native Tuya App SDK** pairs the device (`MethodChannel('net.nestap.app/tuya_pairing')`).
3. `POST /v1/devices/import` adds it to the Nestap home.

Steps 1 and 3 are done (`TuyaPairingRepository`). Step 2 needs a small native plugin on each platform once the Tuya App SDK licence is in place:

| Method | Arguments | Returns | Errors (`PlatformException.code`) |
|--------|-----------|---------|-----------------------------------|
| `pairWifi` | `uid, secret, tuyaHomeId, region, ssid, password, timeoutSec` | Tuya `devId` | `TIMEOUT`, `WIFI_5GHZ`, others |
| `stopPairing` | – | – | – |

Until then, demo mode uses `DemoTuyaSdkBridge`. A real build without the plugin shows "Device pairing is not available in this build yet".

## Next steps

- Native Tuya pairing plugin (Android + iOS), after the SDK licence.
- Localisation (`flutter_localizations` + ARB files; Bangla and English).
- Bundle the Lato font and generate app icons from `assets/images/nestap_logo.png` (`flutter_launcher_icons`).
- Energy history screens (`GET /v1/devices/{id}/energy`), device settings (rename, move room, remove), home members and sharing.
- Push notifications (FCM/APNs) registration via `POST /v1/push-tokens`.
- Crash reporting in `bootstrap.dart`.
