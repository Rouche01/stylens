# AGENTS.md

Guidance for AI coding agents working on **Stylens** (`gostylens`) — a Flutter mobile app that is a personal stylist: capture outfits, style-analysis sessions, closet browsing, and subscriptions.

## Stack

- **Flutter / Dart** — SDK `^3.9.0`, package name `gostylens`
- **State** — `Provider` + `ChangeNotifier` managers; DI via **GetIt** (`locator` in `lib/core/config/dependency_injection.dart`)
- **Routing** — `go_router` (`lib/navigation/`); auth gating via `AuthFlowController`
- **Backend** — Supabase auth + Dio HTTP API (`lib/core/services/api_service/`)
- **Monetization** — RevenueCat (`purchases_flutter`)
- **Analytics / attribution** — PostHog, AppsFlyer, Firebase Messaging
- **Fonts** — Metropolis (UI), ClashDisplay (display)

## Layout

| Path | Purpose |
|------|---------|
| `lib/main.dart` | Bootstrap, env load, `runApp`, theme, `MultiProvider` |
| `lib/core/config/` | `EnvConfig`, GetIt setup, feature flags |
| `lib/core/managers/` | App state (`*Manager` ChangeNotifiers) |
| `lib/core/services/` | API clients, analytics, realtime, feature flags |
| `lib/navigation/` | Routes, auth flow, router |
| `lib/pages/` | Screens (closet, capture, auth, onboarding, paywall, …) |
| `lib/widgets/` | Shared UI |
| `lib/models/` | Data models + API response types |
| `test/` | Unit/widget tests (CI runs `flutter test`) |
| `docs/` | Feature plans and HTML UI previews |
| `ios/fastlane/`, `android/fastlane/` | Store / TestFlight / Play deploy |

## Environment

Env is selected with `--dart-define=ENV=…` (default `development`). Files: `.env.development`, `.env.staging`, `.env.production` (gitignored). Template: `.env.example`.

```bash
# Local (default loads .env.development)
flutter run

# Explicit env
flutter run --dart-define=ENV=staging
flutter run --dart-define=ENV=production
```

`EnvConfig.init()` fails fast if required keys are missing. Android emulators rewrite `localhost` / `127.0.0.1` API hosts to `10.0.2.2`.

**Never commit** `.env*`, keystores, or Fastlane secrets. CI copies `.env.example` into placeholder `.env.*` for the asset bundle before tests.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/closet_manager_test.dart   # single file
```

Deploy: GitHub Actions (`.github/workflows/deploy_ios.yml`, `deploy_android.yml`) + Fastlane; prefer existing lanes over ad-hoc release scripts.

## Conventions

1. **Package imports** — Prefer `package:gostylens/...` over relative imports across folders.
2. **Managers** — Put durable app state in `lib/core/managers/` as `ChangeNotifier`s; register in GetIt; expose via `ChangeNotifierProvider.value` in `main.dart` when UI must listen.
3. **API** — Extend patterns in `lib/core/services/api_service/` (base client + auth interceptor). Keep models in `lib/models/`.
4. **Routes** — Add paths to `AppRoutes` (`lib/navigation/app_routes.dart`); wire deep links through `lib/core/navigation/deep_link/`. Do not scatter magic path strings.
5. **Feature flags** — Keys live in `lib/core/config/feature_flags.dart`; keep in sync with API `GET /config/features` and PostHog `$feature/` props.
6. **UI** — Match existing Metropolis / green theme (`darkGreen` / `limeGreen` / `lightGreen` in `main.dart`). Reuse widgets under `lib/widgets/` and closet pages under `lib/pages/closet/`.
7. **Lints** — `analysis_options.yaml` (flutter_lints). Several `prefer_const_*` rules are intentionally off; do not mass-enable them.
8. **Tests** — Prefer focused unit/widget tests next to the change. Mirror patterns in `test/` (fake async, injected deps on managers). Run `flutter test` before finishing non-trivial changes.
9. **Scope** — Change only what the task needs. Do not rewrite unrelated managers or regenerate Fastlane/CI unless asked.

## Auth & navigation (read first when touching flows)

- `AuthFlowController` owns auth stages; GoRouter redirects depend on it.
- Deep links / push open-navigation wait until `AuthStage.userReady` (`DeepLinkService.setNavigationReady`).
- Splash: native splash preserved until auth loading paints; bootstrap has a 25s timeout.

## Closet & sessions

Closet identity/browse and style-analysis sessions are high-churn areas. Prefer reading:

- `lib/core/managers/closet_manager.dart`
- `lib/core/managers/style_analysis_session/`
- Matching plans under `docs/plan_closet_*.md` when implementing planned UX

## Do not

- Commit secrets or real `.env` values
- Bypass GetIt for services that are already registered
- Invent new state libraries (Riverpod, Bloc, etc.) without an explicit request
- Edit `build/`, generated plugin caches, or Fastlane credential files
