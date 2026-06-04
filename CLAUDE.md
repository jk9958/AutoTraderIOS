# AutoTrader iOS — Agent Context

Native SwiftUI (MVVM) iOS client for a FastAPI options-trading server. Controls trading engines and monitors live P&L over HTTPS.

> This file is committed to the repo so any machine's agent gets the same context after `git pull`. Keep it updated when conventions or the API change.

> **Active plan:** the novice-first UX redesign + full API integration roadmap lives in [`docs/PLAN_NOVICE_UX_AND_API.md`](docs/PLAN_NOVICE_UX_AND_API.md). To continue the work (incl. from Claude mobile after a session reset), start at that doc's §15, then §11 Milestone A.

## Server (source of truth)

- **Backend repo:** `Auto_Option` (FastAPI). Lives beside this repo (`../Auto_Option`) on the primary dev machine; not present on every machine. Main API file: `src/api_server.py`.
- Base URL: `https://trader.allweatheralgo.com` (public HTTPS, no auth header — private network). Editable in Settings, stored in `UserDefaults` key `serverBaseURL`.
- **The server code is authoritative over any hand-written API doc.** A previously-supplied `ios_api_reference.md` had a WRONG `/margin/iron-condor` shape and wrong `/metrics` bucket keys. Always verify response shapes against `src/api_server.py` if available.

## ⚠️ Critical: JSON decode convention

The shared `JSONDecoder` in `Networking/APIClient.swift` uses `keyDecodingStrategy = .convertFromSnakeCase`. This was verified empirically:

| Model kind | Rule |
|---|---|
| **Decodable response models** | Use camelCase properties, **NO** `CodingKeys`. The strategy maps `started_at` → `startedAt` automatically. Adding snake_case `CodingKeys` (e.g. `case startedAt = "started_at"`) **silently decodes to nil** — the strategy converts the JSON key *before* matching, so it never matches the snake_case raw value. |
| **Encodable param structs** (`IronCondorParams`, `VixScalpParams`, `TrendAgentParams`) | Encoded with a *plain* `JSONEncoder()` (no key strategy) → they **DO** need explicit snake_case `CodingKeys`. Keep them. |
| **Dictionary fields** (`[String: String]`, `[[String: String]]`, `[String: Double]`) | The strategy does NOT touch dictionary keys — they stay snake_case. Access trade-row keys as `trade["entry_price"]` (snake_case). |

This bug had silently nil'd `ServerStatus.startedAt/.exitCode/.paperTrading/.nextExpiry`, `TokenResponse.updatedAt`, `MetricsResponse.per5min` in production. Don't reintroduce it.

## Architecture

- `AppState` (`@MainActor` `ObservableObject`) — shared status, 5s `/status` polling, lifecycle pause/resume, owns the `APIClient`.
- `APIClient` (struct) — all calls; per-request ephemeral `URLSession`; `convertFromSnakeCase` decoder; `TrustDelegate` for server-trust.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — types default to `@MainActor`.
- One VM per feature (`DashboardVM`, `TradeVM`, `TradesVM`, `LogsVM`, `SettingsVM`, `TrendAgentVM`).
- LIVE (non-dry-run) launches require a `confirmationDialog`. Form values persist to `UserDefaults`.
- OAuth (Fyers/Kite/TradeSmart) via `SFSafariViewController` sheet; on dismiss re-fetch `/status` to confirm the token flipped.

## UI / Design language

Modernized to native iOS + glass materials (HIG-aligned). Use `glassCard()` / `thinGlassCard()` modifiers from `Support/Theme.swift` (`.ultraThinMaterial` / `.thinMaterial`, continuous corners, gradient hairline border, soft shadow). Prefer native typography (`.headline`, `.subheadline`, `.caption`…), `Form`/`Section` for input, native charts (Swift Charts). Supports light + dark. Avoid web-style flat cards, borders, tiny fonts. Theme still exposes legacy color aliases for compatibility.

## Tabs

1. **Status** (`DashboardView`) — engine status card (pulsing dot, mode badge, uptime, stop), broker-auth card (token chips + login rows).
2. **Engines** (`EnginesListView`) — multi-engine management via the **mobile API v1** (see below). List (heartbeat status, swipe start/stop/delete, context menu), `CreateEngineView` (broker × strategy form), `EngineDetailView` (status, start/stop/restart, config inspector + dry-run PATCH, broker-token PUT). Writes require the X-API-Key.
3. **Trade** (`TradeView`) — strategy cards → Iron Condor (full form + margin estimate), VIX Scalp (configurable params), Options.
4. **Trend** (`TrendAgentView`) — Trend Agent: status/start/stop, launch config, open positions, **Adaptive Progress** (Swift Charts: win-rate trend, cumulative & per-cycle P&L → `TrendAdaptiveProgressView`), evolved params (`TrendLearningView`), trades/logs.
5. **Logs** (`LogsView`) — engine + API logs.
6. **Positions** (`TradesView`) — `MTMCard` live P&L + trade-history cards.

> 6 tabs: on compact iPhone the last items collapse into the system "More" tab. Reorder in `RootTabView` if different prominence is wanted.

## Mobile API v1 — multi-engine management (X-API-Key)

Server `mobile`-tagged endpoints (`/api/v1/...`) are a separate multi-engine control plane that creates/operates arbitrary `broker × strategy` engines via `systemctl` — **distinct from the legacy single-engine `/start/* · /stop · /status` control.** Write endpoints require the `X-API-Key` header; GET reads are open.

- Key lives in the **Keychain** (`KeychainStore`, account `mobile-api-key`) → `AppState.apiKey` → `APIClient.apiKey` → sent as `X-API-Key`. Never UserDefaults.
- `APIClient`: `listEngines`, `engineStatus`, `engineConfig`, `createEngine`, `patchEngineConfig`, `engineLifecycle(_:action:)`, `deleteEngine`, `updateEngineToken`, `rotateApiKey`. Models in `Models/EngineModels.swift`; free-form config/params via `Support/JSONValue.swift`.
- Endpoints: `GET /api/v1/engines` · `POST /api/v1/engines` · `GET /api/v1/engines/{id}/status` · `GET|PATCH /api/v1/engines/{id}/config` · `POST /api/v1/engines/{id}/{start,stop,restart}` · `DELETE /api/v1/engines/{id}` · `PUT /api/v1/engines/{id}/token` · `PUT /api/v1/config/api-key`.
- Errors: `401` → `.unauthorized`; `503` (`API_KEY not set on server`) → `.serverKeyNotConfigured`. `engine_id` regex `^[A-Za-z0-9_-]+$`, rotation key ≥ 12 chars (mirrored in `EngineValidation`). Contract tests: `MobileAPIContractTests.swift`.

## API endpoints in use

`GET /status` · `GET /mtm` · `GET /trades` · `GET /logs` · `GET /logs/api` · `POST /logs/clear` · `GET /margin/iron-condor` · `GET /metrics` · `POST /start/iron-condor` · `POST /start/vix-scalp` · `POST /stop` · `POST /token/{fyers,kite,tradesmart/exchange}` · `POST /token/fyers/save-env` · auth URLs `/auth/{fyers,kite,tradesmart}`
Trend Agent: `POST /start/trend-agent` · `POST /stop/trend-agent` · `GET /trend-agent/{status,signals,learning,trades,logs}`

Engine-start endpoints return `409` if an engine is already running. The Trend Agent runs as a **separate process**, concurrent with the main engine.

### Real response shapes (verified against server)
- `/margin/iron-condor` → `margin_required`, `per_lot`, `method` (`"fyers_span"|"formula"`), `spot`, `atm`, `legs{short_pe,long_pe,short_ce,long_ce}`, `lot_size`, `lots`, `qty`.
- `/metrics` `per_5min[]` → `{interval, lines, sent, recv, total, sent_fmt, recv_fmt, total_fmt}`.
- `/trend-agent/learning` → `adaptive_params{}` (from `live_state/adaptive_params.json`), `learning_history[]` (SQLite `trade_memory.db`, newest-first), `trade_summary{}`.

## Build

Project uses Xcode **filesystem-synced groups** (`PBXFileSystemSynchronizedRootGroup`) — new `.swift` files are picked up automatically, no `.pbxproj` edits needed.

```sh
# from AutoTraderIOS/ (the dir containing AutoTraderIOS.xcodeproj)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme AutoTraderIOS \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

Deployment target: iOS 26.2 (Swift Charts and modern SwiftUI fully available).

## Preferences

- Bundle changes into few commits rather than many small ones.
- Terse responses; no trailing summaries.
- Commit/push only when explicitly asked.
