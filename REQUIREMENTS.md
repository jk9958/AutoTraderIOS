# iOS Native App — Requirements Specification

**Product:** Auto Trader Control (iOS client)
**Backend:** `src/api_server.py` — FastAPI "Auto Trader" v2.0.0
**Purpose:** A native iOS app that replaces the HTML dashboard, letting the user authenticate brokers, start/stop trading engines, and monitor logs/trades from anywhere over Tailscale.

---

## 1. Goal & Scope

The FastAPI server already exposes a complete control surface and ships an HTML dashboard. This app is a **native client** for that same API — nothing more, nothing less. It must:

1. Show live engine status and broker token status (the "dashboard details").
2. Trigger every server action through native buttons/forms (no embedded web view).
3. Stream and display engine logs.
4. Surface clear, actionable error and warning messages for every failure mode.

**Out of scope:** the app does not place orders itself, does not talk to brokers directly, and stores no trading logic. All intelligence stays on the server. The app is a thin, well-designed client.

---

## 2. Platform & Tech Stack

| Item | Requirement |
|------|-------------|
| Language | Swift 5.9+ |
| UI framework | SwiftUI |
| Min iOS version | iOS 16.0 |
| Architecture | MVVM — `APIClient` (networking) → `ViewModel` (state) → `View` |
| Networking | `URLSession` with `async/await`; `Codable` models |
| Concurrency | Swift Concurrency (`async/await`, `@MainActor` view models) |
| Persistence | `UserDefaults` for server base URL + last-used form values |
| Dependencies | None required (pure SwiftUI + Foundation). No third-party libs. |

---

## 3. Server Connection

- The server runs on the user's Windows machine, reachable over **Tailscale** at `http://100.124.30.59:8000` (current known IP).
- The base URL **must be user-editable** in a Settings screen and persisted — the Tailscale IP or port can change.
- All requests use plain HTTP (Tailscale provides the encrypted tunnel). The app must allow HTTP to this host:
  - Add an **App Transport Security exception** in `Info.plist` for arbitrary loads (or scope it to the Tailscale IP).
- No authentication header is needed — the server is unauthenticated and relies on Tailscale for access control. Do **not** build a login screen for the server itself.
- Provide a **"Test Connection"** button in Settings that calls `GET /health` and reports reachability.

---

## 4. API Reference (contract the app must implement)

Base URL: `{server_base_url}` (e.g. `http://100.124.30.59:8000`)

### 4.1 `GET /health`
Liveness probe. Always `200 {"status": "ok"}` when reachable. Used by Test Connection.

### 4.2 `GET /status`
Primary dashboard data source. Poll every **5 s** while the app is foregrounded.
```json
{
  "running": true,
  "engine": "iron-condor [dry-run]",
  "started_at": "2026-05-21T09:32:10.123456",
  "exit_code": null,
  "log_lines": 142,
  "tokens": { "fyers": "updated 09:15", "kite": "not set" },
  "paper_trading": "false",
  "next_expiry": "26521"
}
```
- `running` (bool) → engine status pill.
- `engine` (string|null) → engine name; `null` when stopped.
- `started_at` (ISO8601|null) → render as `HH:mm:ss` + elapsed time.
- `exit_code` (int|null) → if non-null and non-zero while not running, show a warning ("engine exited with code N").
- `tokens` (dict) → per-broker badge. Value contains `updated`/`loaded` → green; otherwise orange/grey.
- `paper_trading` (string `"true"`/`"false"`) → PAPER (orange) vs LIVE (red) banner.
- `next_expiry` (string) → prefill the Iron Condor expiry field.

### 4.3 `GET /logs?lines=N`
`N` is 1–500 (server clamps). Poll every **5 s** on the Logs screen.
```json
{ "source": "live", "lines": ["09:32:10 ENTRY ...", "09:32:25 ..."] }
```
- `source` is `"live"` (in-memory buffer) or `"file"` (today's log file). Show this as a small caption.
- `lines` is an ordered array, oldest → newest.

### 4.4 `GET /trades`
```json
{ "trades": [ { "entry_time": "...", "pnl": "1530", ... } ] }
```
- `trades` is an array of CSV rows as string→string dictionaries. **Columns are dynamic** — do not hard-code keys. Render as a list of cards or a horizontally scrollable table built from `Array(row.keys)`.
- Empty array → "No trades recorded yet" empty state.

### 4.5 `POST /token/fyers` and `POST /token/kite`
Body: `{ "access_token": "<string>" }`
- Success `200`: `{ "status": "ok", "broker": "fyers", "updated_at": "09:15" }`
- Error `400`: `{ "detail": "access_token must not be empty" }` — also surfaces if the server `.env` file is missing (`FileNotFoundError`).

### 4.6 `GET /auth/fyers` (OAuth)
- This is a **browser redirect** flow, not a JSON API. The app must open it in `SFSafariViewController` / `ASWebAuthenticationSession`, **not** call it with `URLSession`.
- It 302-redirects to the Fyers login page, then back to `GET /auth/fyers/callback`, which returns an HTML success/failure page.
- After the web session closes, the app should re-fetch `GET /status` to confirm `tokens.fyers` flipped to `updated HH:mm`.
- If `FYERS_CLIENT_ID` / `FYERS_SECRET_KEY` are unset, the endpoint returns `400` HTML — detect a non-2xx and tell the user to configure `.env` on the server.

### 4.7 `POST /start/iron-condor`
Body (all fields; defaults shown):
```json
{
  "expiry": "26521",        // required, no default — string
  "instrument": "nifty",    // "nifty" | "banknifty"
  "lots": 1,                // int 1–50
  "spread_pts": 400,        // int, min 50
  "wing_pts": 200,          // int, min 50
  "profit_target": 0.50,    // float 0.1–1.0
  "sl_multiplier": 1.0,     // float 0.5–5.0
  "entry_start": "09:30",   // "HH:MM"
  "entry_cutoff": "11:00",  // "HH:MM"
  "eod_exit": "15:15",      // "HH:MM"
  "dry_run": true           // bool — MUST default true
}
```
- Success `200`: `{ "status": "started", "engine": "iron-condor [dry-run]", "command": [...] }`
- Error `409`: `{ "detail": "Engine '...' already running. POST /stop first." }`
- Error `422`: Pydantic validation error — `detail` is an **array** of field errors, not a string (see §7.2).

### 4.8 `POST /start/scalping` and `POST /start/options`
Body: `{ "dry_run": true }`
- Success `200`: `{ "status": "started", "engine": "scalping [dry-run]" }`
- Error `409`: same as above.

### 4.9 `POST /stop`
No body.
- `{ "status": "stopped", "engine": "iron-condor [LIVE]" }` or `{ "status": "not_running" }`.
- Treat `not_running` as a benign info message, not an error.

---

## 5. Screens & Navigation

A `TabView` with four tabs, plus a Settings sheet.

### 5.1 Dashboard (home tab)
The native equivalent of the HTML dashboard. Top to bottom:

1. **Header** — "Auto Trader" + a status badge (Running / Stopped).
2. **Engine Status card**
   - Running/Stopped pill + PAPER/LIVE pill.
   - Engine name, start time, elapsed duration (live ticking).
   - If `exit_code` non-zero and not running → red warning row.
   - **Stop Engine** button — destructive style; disabled when nothing is running.
3. **Auth Tokens card**
   - Fyers badge + Kite badge, colored by status.
   - **"Login with Fyers"** button → OAuth web session (§4.6).
   - **"Paste token manually"** — expandable section with a secure text field + Save for each broker.
4. **Quick actions** — shortcut to the Trade tab.

Pull-to-refresh re-fetches `/status`. Auto-poll every 5 s while foregrounded; pause polling in background.

### 5.2 Trade (start engines tab)
Three collapsible sections — Iron Condor, Scalping, Options.

- **Iron Condor form** — all fields from §4.7 with native inputs:
  - Expiry: text field, prefilled from `next_expiry`.
  - Instrument: segmented control (NIFTY / BANKNIFTY).
  - Lots / spread / wing: steppers or numeric fields with the documented min/max.
  - Profit target / SL multiplier: sliders or numeric fields.
  - Entry start / cutoff / EOD: time-style fields.
  - **Dry run toggle — ON by default.**
  - **Launch** button.
- **Scalping / Options** — just a Dry-run toggle + Launch button.
- **LIVE-mode confirmation:** if dry-run is OFF, show a blocking confirmation alert ("⚠️ LIVE mode — real orders will be placed.") before sending. This mirrors the dashboard and is mandatory.
- Persist the last-used Iron Condor values in `UserDefaults` so the form is pre-filled next time.
- Disable Launch buttons while an engine is already running; show "Stop the current engine first."

### 5.3 Logs (monitor tab)
- Scrolling, monospaced log view, newest at bottom, auto-scroll to bottom on new lines.
- Poll `GET /logs?lines=200` every 5 s.
- Caption showing `source` (live buffer vs file).
- Controls: pause/resume auto-scroll, manual refresh, line-count picker (50/100/200/500).
- Empty state: "No logs yet."

### 5.4 Trades (history tab)
- List of trades from `GET /trades`, newest first.
- Each row = a card built dynamically from the CSV columns; highlight a P&L column green/red if present.
- Pull-to-refresh.
- Empty state: "No trades recorded yet."

### 5.5 Settings (sheet from Dashboard)
- Server base URL field (persisted).
- **Test Connection** button → `GET /health`, shows ✅/❌.
- App version + a short note that access requires Tailscale to be connected.

---

## 6. UI / UX Requirements

- **Visual language:** dark theme matching the existing dashboard — background `#0d0d0f`, cards `#1c1c1e`, text `#e2e2e7`, rounded 14px cards. Accent colors: green `#27ae60` (go/healthy), blue `#3a7bd5` (neutral actions), orange `#d68910` (warning/paper), red `#c0392b` (stop/live/error).
- Support Dynamic Type and Dark Mode (dark is the default and only required theme).
- Every network action must show a **loading state** (button spinner / disabled state) — never a frozen UI.
- Use **haptic feedback**: success notification on engine start, warning haptic on LIVE confirmation, error haptic on failures.
- Destructive actions (Stop, LIVE launch) require a confirmation dialog.
- Polling must **pause when the app is backgrounded** and resume on foreground (battery + avoids stale bursts).
- Show a persistent, dismissible banner when the server is unreachable, so the user always knows the connection state.
- Empty states for logs and trades must be friendly, not blank screens.
- The LIVE/PAPER status must be **impossible to miss** — a full-width colored banner, not a small pill.

---

## 7. Error & Warning Handling

Error handling is a first-class requirement. Every API call must map to a clear user message.

### 7.1 Transport-level failures
| Condition | User message | Treatment |
|-----------|-------------|-----------|
| No network / Tailscale down | "Can't reach the server. Check that Tailscale is connected and the server is running." | Banner + retry button |
| Connection timeout | "Server timed out. It may be starting up — try again." | Banner + retry |
| Wrong base URL | "No server at {url}. Check the address in Settings." | Banner, deep-link to Settings |

- Use a request timeout of ~10 s for actions, ~6 s for polling.
- Polling failures should be **silent after the first** (just keep the banner) — do not spam alerts every 5 s.

### 7.2 HTTP error responses
The server returns errors in two shapes — the app must handle both:

1. **`HTTPException`** → `{ "detail": "<string>" }` (e.g. 400, 409). Show `detail` verbatim.
2. **Validation `422`** → `{ "detail": [ { "loc": [...], "msg": "...", "type": "..." } ] }` — `detail` is an **array**. Join the `msg` fields, or map `loc` back to the offending form field and highlight it.

| Status | Meaning | App behavior |
|--------|---------|--------------|
| 400 | Bad input / `.env` missing on server | Alert with `detail`; for `.env` errors, explain it's a server-side config problem |
| 409 | Engine already running | Alert: "An engine is already running. Stop it first." + offer a Stop button in the alert |
| 422 | Field validation failed | Inline field errors on the Trade form; don't submit |
| 5xx | Server crash | "The server hit an error. Check the server logs." |

### 7.3 Domain-level warnings (200 OK but noteworthy)
- `/stop` → `{ "status": "not_running" }`: info toast "No engine was running", not an error.
- LIVE mode (`dry_run = false`): mandatory pre-send confirmation; after start, show a persistent LIVE banner.
- OAuth callback returns an HTML page — the app can't parse JSON. After the web session ends, **verify success via `/status`**; if `tokens.fyers` did not change, warn "Fyers login may not have completed — try again."
- `exit_code` non-zero after an engine stops on its own → warning card "Engine exited unexpectedly (code N). Check logs."

### 7.4 General rules
- Never show a raw stack trace, raw JSON, or an HTTP status number alone — always a human sentence.
- Distinguish **error** (red, something failed) from **warning** (orange, attention needed) from **info** (neutral).
- Every failed action must remain **retryable** — leave the form populated, re-enable the button.

---

## 8. Data Models (Swift `Codable` sketch)

```swift
struct ServerStatus: Codable {
    let running: Bool
    let engine: String?
    let startedAt: String?      // started_at
    let exitCode: Int?          // exit_code
    let logLines: Int           // log_lines
    let tokens: [String: String]
    let paperTrading: String    // paper_trading — "true"/"false"
    let nextExpiry: String      // next_expiry
}

struct LogsResponse: Codable {
    let source: String
    let lines: [String]
}

struct TradesResponse: Codable {
    let trades: [[String: String]]   // dynamic columns
}

struct StartResponse: Codable {
    let status: String
    let engine: String?
}

struct TokenResponse: Codable {
    let status: String
    let broker: String
    let updatedAt: String       // updated_at
}

struct APIErrorDetail: Codable {        // 422 element
    let loc: [String]
    let msg: String
    let type: String
}
// `detail` decodes as either String or [APIErrorDetail] — handle both.
```

Use a `keyDecodingStrategy = .convertFromSnakeCase` decoder, or explicit `CodingKeys`.

---

## 9. Acceptance Criteria

The app is complete when:

1. Dashboard reflects `/status` accurately and updates within 5 s of a server-side change.
2. Every endpoint in §4 is reachable through a native control — no web views except the Fyers OAuth flow.
3. Iron Condor, Scalping, and Options engines can each be started and stopped from the app.
4. LIVE mode cannot be triggered without an explicit confirmation dialog.
5. Logs stream and auto-scroll; Trades render with dynamic columns.
6. Fyers OAuth completes in `ASWebAuthenticationSession` and the token badge turns green afterward.
7. Every failure in §7 produces a specific, human-readable message — verified by testing with the server stopped, a wrong URL, an already-running engine, and an empty token.
8. Polling pauses in the background and resumes on foreground.
9. Server base URL is configurable and persisted.

---

## 10. Suggested File Structure

```
AutoTrader/
├── App/                  AutoTraderApp.swift, RootTabView.swift
├── Networking/           APIClient.swift, APIError.swift, Endpoints.swift
├── Models/               ServerStatus.swift, LogsResponse.swift, ...
├── ViewModels/           DashboardVM.swift, TradeVM.swift, LogsVM.swift, TradesVM.swift
├── Views/
│   ├── Dashboard/        DashboardView.swift, EngineStatusCard.swift, TokenCard.swift
│   ├── Trade/            TradeView.swift, IronCondorForm.swift
│   ├── Logs/             LogsView.swift
│   ├── Trades/           TradesView.swift
│   └── Settings/         SettingsView.swift
├── Components/           StatusPill.swift, Banner.swift, LoadingButton.swift
└── Support/              Theme.swift, Haptics.swift, Polling.swift
```

---

## 11. Future Enhancements (not required for v1)

- Push notifications when an engine stops or exits unexpectedly (would need a server-side push).
- Face ID lock on app open before allowing LIVE launches.
- Charts for the trades P&L history.
- A `GET /status` widget for the iOS home screen.
