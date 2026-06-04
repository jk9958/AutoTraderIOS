# AutoTrader iOS

A native SwiftUI iPhone app for running and monitoring automated options-trading
**bots** on a [FastAPI backend](https://github.com/jk9958/Auto_Option). Designed to
be usable by non-technical people: create a bot, try it in **Practice mode** (no
real money), connect a broker, and watch live results — without reading docs.

> **New here as a user?** Read the **[User Guide](docs/USER_GUIDE.md)**.
> **Working on the code?** Start with **[CLAUDE.md](CLAUDE.md)** (conventions) then this file.

## What it does

- **Bots** — create/start/stop/restart/delete independent `broker × strategy`
  trading bots (server-side `systemctl` engines), with a guided 4-step wizard.
- **Practice & Live** — bots default to Practice (simulated); going Live requires
  explicit confirmation and is clearly badged.
- **Home dashboard** — what's running, broker status, open P&L, alerts, and the
  next action at a glance.
- **Activity** — open positions (live P&L), trade history, and computed stats.
- **Brokers** — one-tap web login (OAuth) for Fyers / Zerodha (Kite) / TradeSmart,
  including one-tap **reconnect** that re-syncs a bot's broker login server-side.
- **System check** — plain-language component health (`/health/deep`).
- **Advanced** — the original engineer screens (engine dashboard, manual Iron
  Condor / VIX Scalp, Trend Agent, raw logs) are preserved under **More → Advanced**.

## Stack & requirements

| | |
|---|---|
| Language / UI | Swift, SwiftUI (MVVM) |
| Min iOS | **26.2** (Swift Charts + modern SwiftUI) |
| Dependencies | **None** (no third-party packages) |
| Persistence | `UserDefaults` (server URL) + **Keychain** (access code); no local DB |
| Backend | `https://trader.allweatheralgo.com` (editable in Settings) |

## Build

```sh
# from AutoTraderIOS/ (the directory containing AutoTraderIOS.xcodeproj)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme AutoTraderIOS \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

Open `AutoTraderIOS.xcodeproj` in Xcode to run on a simulator/device. The project
uses Xcode **filesystem-synced groups**, so new `.swift` files are picked up
automatically — no `.pbxproj` edits needed.

## First run

1. Launch → a 4-step onboarding appears.
2. Enter your **admin access code** (your provider gives you this; required to
   create/control bots). You can skip and explore first.
3. Optionally connect a broker (More → Brokers).
4. Create a bot from the **Bots** tab — it starts in Practice mode.

Full walkthrough: **[docs/USER_GUIDE.md](docs/USER_GUIDE.md)**.

## Architecture (at a glance)

- `AppState` (`@MainActor`) owns the `APIClient`, app-scoped polling, network
  reachability, and the shared **`EnginesStore`** (single source of truth for the
  bot list, so all tabs agree).
- One view-model per feature; `APIClient` is a `struct` behind the `EngineServicing`
  protocol (dependency injection for tests).
- Shared building blocks: `AppStatus`/`StatusChip`, `FriendlyError` (no raw HTTP
  shown to users), `Format` (crash-safe number formatting), `KeychainStore`.
- JSON decode convention is documented in [CLAUDE.md](CLAUDE.md) — **do not** add
  snake_case `CodingKeys` to `Decodable` response models.

## API coverage

Consumes 38 of 40 documented backend operations (the 2 legacy `/engines*`
endpoints are superseded by the `/api/v1/engines` mobile API). Mobile-API writes
require the `X-API-Key` header (the "admin access code"); reads are open. The
backend (`src/api_server.py`) is the source of truth for response shapes.

## Repository layout

```
AutoTraderIOS/AutoTraderIOS/
  Networking/   APIClient, APIError, EngineService (protocol)
  Models/       Engine / diagnostics / MTM / trades / logs models
  ViewModels/   AppState, EnginesStore, Home/Activity/Diagnostics/Settings VMs …
  Views/        Home, Bots, Activity, Brokers, More, Engines (detail),
                Onboarding, Settings, Dashboard/Trade/TrendAgent (advanced)
  Support/      Theme, AppStatus, FriendlyError, Format, KeychainStore,
                NetworkMonitor, Analytics, Haptics, JSONValue
  Components/   MTMCard, StatusPill, ConnectionBanner …
AutoTraderIOSTests/        contract + view-model unit tests
docs/                      USER_GUIDE, PLAN, SPEC
```

## Docs

- **[User Guide](docs/USER_GUIDE.md)** — for end users.
- **[CLAUDE.md](CLAUDE.md)** — agent/dev context & conventions.
- **[REQUIREMENTS.md](REQUIREMENTS.md)** — product specification.
- **[docs/PLAN_NOVICE_UX_AND_API.md](docs/PLAN_NOVICE_UX_AND_API.md)** — UX + API roadmap.
- **[docs/SPEC_engine_token_sync.md](docs/SPEC_engine_token_sync.md)** — broker token-sync contract.

## Related

- Backend: [`Auto_Option`](https://github.com/jk9958/Auto_Option) · API: [`src/api_server.py`](https://github.com/jk9958/Auto_Option/blob/develop/src/api_server.py)

## Status

App and test targets build clean. The test suite must be **run** on a machine with
an installed simulator runtime before release:

```sh
xcodebuild test -scheme AutoTraderIOS -destination 'platform=iOS Simulator,name=iPhone 16'
```
