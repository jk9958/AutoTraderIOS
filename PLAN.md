# iOS App — Build Plan (Updated)

Server: `https://trader.allweatheralgo.com`  
API reference: `docs/ios_api_reference.md` in the server repo.

---

## Current State

The app has a 4-tab shell: **Dashboard · Trade · Logs · Trades**.

| Area | File(s) | Status |
|------|---------|--------|
| App shell + TabView | `RootTabView.swift`, `AutoTraderIOSApp.swift` | Done |
| `APIClient` — fetch, error handling, TrustDelegate | `Networking/APIClient.swift` | Done (gaps — see §1) |
| `AppState` — polling, connection state | `ViewModels/AppState.swift` | Done |
| Settings sheet (URL only) | `Views/Settings/SettingsView.swift` | Partial — no API key |
| Dashboard: engine status, stop button, Fyers/Kite auth | `Views/Dashboard/DashboardView.swift` | Done (old API) |
| Iron Condor launch form | `Views/Trade/IronCondorForm.swift` | Done (old API, gaps) |
| Scalping / Options simple forms | `Views/Trade/TradeView.swift` | Done (old API) |
| Logs: streaming from `/logs` | `Views/Logs/LogsView.swift` | Partial — old endpoint |
| Trades list | `Views/Trades/TradesView.swift` | Done (basic) |
| MTMCard, StatusPill, LoadingButton, ConnectionBanner | `Components/` | Done |
| Theme, Haptics | `Support/` | Done |

---

## Pending Work

### 1. X-API-Key Auth — `APIClient` + `SettingsView`  ⚠️ Must do first

`APIClient` never sends the `X-API-Key` header. All new v2 write endpoints
(`POST /api/v2/engines/launch`, `PUT /api/v1/config/api-key`, etc.) will return
`401` until this is added.

- [ ] Add `apiKey: String` property to `APIClient`; inject as `X-API-Key` header
      on every request inside `urlRequest(_:method:timeout:)` and `performURL(_:timeout:)`
- [ ] Store the API key in **Keychain** (not `UserDefaults`) — add `KeychainHelper.swift`
- [ ] `SettingsView`: add API key `SecureField` (read/write Keychain); show a
      masked preview (`••••••••<last4>`)
- [ ] `AppState`: pass api key into `APIClient` init; rebuild `client` whenever
      the key changes (same pattern as `serverBaseURL`)
- [ ] Test connection button should call `GET /health` with the key and report
      `401 Unauthorized` distinctly from network errors

---

### 2. Migrate to v2 API — `APIClient` methods

Current launch/stop calls use legacy endpoints. Replace:

| Old | New |
|-----|-----|
| `POST /start/iron-condor` | `POST /api/v2/engines/launch` |
| `POST /start/scalping` | `POST /api/v2/engines/launch` |
| `POST /stop` | `POST /api/v2/engines/{engine_id}/stop` |
| `GET /status` | `GET /api/v1/engines` (heartbeat list) + `GET /health/deep` |

- [ ] Add `func launchEngine(_ req: LaunchRequest) async throws -> LaunchResponse`
- [ ] Add `func stopEngine(id: String) async throws`
- [ ] Add `func engines() async throws -> [EngineHeartbeat]`
- [ ] Add `func healthDeep() async throws -> HealthDeepResponse`
- [ ] Add `func brokerHealth() async throws -> BrokerHealthResponse`
- [ ] Add `func brokerApiLog(lines: Int) async throws -> LogsResponse`
- [ ] Add `func logFiles() async throws -> LogFilesResponse`
- [ ] Add `func logFile(name: String, lines: Int) async throws -> LogFileResponse`
- [ ] Add `func rotateApiKey(newKey: String) async throws`
- [ ] Keep old `status()`, `startIronCondor()`, `startEngine()` until all call
      sites are migrated, then delete

New models needed:
- `Engine.swift` — `EngineHeartbeat` (`engine_id`, `status`, `pid`, `last_beat`, `stale`)
- `BrokerHealth.swift` — per-broker token status map
- `LogFilesResponse.swift` — update `LogsResponse`; add `LogFile` with `name`, `size_kb`, `compressed`, `log_date`

---

### 3. Engines Tab — replace Trade tab

The Trade tab lists strategies but has no visibility into running engines.
Replace or rename it to **Engines**, mirroring the web dashboard.

- [ ] Rename `TradeView` → `EnginesView` (tab label, icon: `cpu`)
- [ ] Top section: running engine list from `GET /api/v1/engines` (15 s poll)
      — each card shows: `engine_id`, strategy badge, broker badge, status pill
      (RUNNING=green / STALE=yellow / STOPPED=grey), last-beat age, **Stop** button
- [ ] Launch sheet (sheet, not NavigationLink):
  - Strategy picker: **Iron Condor · VIX Scalp · Trend**
  - Broker picker: **Fyers · Kite · Tradesmart**
  - Instrument picker (Iron Condor only): **NIFTY · SENSEX** — fix current BANKNIFTY
  - Expiry picker (Iron Condor only): `Picker` with next 4 weekly dates auto-computed
    (NIFTY = Tuesday, SENSEX = Thursday — see `ExpiryHelper.swift` below)
  - Lots stepper, dry-run toggle
  - Submit → `POST /api/v2/engines/launch`
- [ ] Keep Iron Condor advanced params (spread, wings, profit target, SL, schedule,
      margin estimate) as a disclosure group inside the launch sheet

**`ExpiryHelper.swift`** (new file):
```swift
func weeklyExpiries(instrument: String) -> [(label: String, fyers: String)] {
    let targetWeekday = instrument == "sensex" ? 5 : 3  // Thu=5, Tue=3
    var dates: [(label: String, fyers: String)] = []
    var d = Date()
    while dates.count < 4 {
        d = Calendar.current.date(byAdding: .day, value: 1, to: d)!
        if Calendar.current.component(.weekday, from: d) == targetWeekday {
            dates.append((label: formatted(d), fyers: fyersCode(d)))
        }
    }
    return dates
}

private func fyersCode(_ d: Date) -> String {
    let c = Calendar.current
    let yy = String(c.component(.year, from: d) % 100)
    let m  = c.component(.month, from: d)
    let dd = String(format: "%02d", c.component(.day, from: d))
    let mc = m <= 9 ? String(m) : ["O","N","D"][m - 10]
    return yy + mc + dd
}
```

---

### 4. Brokers Tab — split out from Dashboard

Broker auth is currently buried in Dashboard. Add a dedicated **Brokers** tab.

- [ ] New tab between Engines and Logs (icon: `link`)
- [ ] `BrokersView.swift` — three broker cards (Fyers / Kite / Tradesmart)
- [ ] Each card shows token status from `GET /api/v2/broker-health`
- [ ] **Fyers**: "Login with Fyers" → `ASWebAuthenticationSession` (already wired
      in `DashboardVM`; move logic to `BrokersVM`)
      + paste token fallback (`POST /token/fyers`)
- [ ] **Kite**: paste token → `POST /token/kite`
- [ ] **Tradesmart**: auth code paste → `POST /token/tradesmart/exchange`
- [ ] Remove broker auth section from `DashboardView` once Brokers tab is live
- [ ] `BrokersVM.swift` (new) — token save state, auth URL, reload

---

### 5. Logs Upgrade — file picker + date picker + Broker API tab

Current `LogsView` streams from the old `/logs` endpoint with no file selection.

- [ ] Add tab bar inside LogsView: **Engine Logs · Broker API**

**Engine Logs tab:**
- [ ] Date picker (`DatePicker`, max = today) — default today
- [ ] On date change → `GET /logs/files`, filter: today → `compressed == false`,
      past → `log_date == "YYYYMMDD"` from selected date
- [ ] File `Picker` (dropdown) showing filtered files
- [ ] Log viewer: `GET /logs/file?name=&lines=300`
- [ ] Live toggle (today only): 5 s poll, auto-scroll to bottom
- [ ] Refresh button

**Broker API tab:**
- [ ] `GET /logs/api?lines=100`, newest first
- [ ] Row color: `REQ` = primary, `RESP 2xx` = green, `RESP 4xx/5xx` = red
- [ ] Live toggle: 5 s poll

Update `LogsVM` to drive both tabs, or split into `EngineLogsVM` + `BrokerApiLogsVM`.

---

### 6. Positions Tab — MTM live view

`MTMCard` component exists but is not wired into a tab.

- [ ] Add **Positions** tab (icon: `chart.bar.fill`) after Brokers
- [ ] `PositionsView.swift` — polls `GET /mtm` (iron condor) every 15 s
- [ ] Shows: spot, entry spot, short/long strikes, net credit, cost-to-close,
      MTM pts + INR, profit target pts, SL pts, lots
- [ ] "No open position" empty state
- [ ] Reuse `MTMCard` component

---

### 7. P&L Tab — chart from trades

- [ ] Add **P&L** tab (icon: `chart.line.uptrend.xyaxis`) after Trades
- [ ] `PnLView.swift` — fetches `GET /trades` on appear
- [ ] Daily bar chart using `Charts` framework (iOS 16+)
- [ ] Cumulative P&L line overlay
- [ ] Summary row: total trades, win rate, total P&L in INR

---

### 8. Alerts Tab

- [ ] Add **Alerts** tab (icon: `bell`) after P&L
- [ ] `AlertsView.swift` — polls `GET /api/v2/alerts` (30 s)
- [ ] Severity color coding: CRITICAL=red, WARNING=orange, INFO=primary
- [ ] "No alerts" empty state

---

### 9. Settings — API key rotation

- [ ] "Rotate API Key" button in Settings → text field for new key →
      `PUT /api/v1/config/api-key` → on success write new key to Keychain
- [ ] Confirmation alert before rotating ("New key is active immediately")

---

### 10. Background Notifications (optional / last)

- [ ] `BGAppRefreshTask` registered in `Info.plist`
- [ ] Background handler polls `GET /health/deep`; fires
      `UNUserNotificationCenter` local notification when status goes DEGRADED/FAILED
- [ ] Request notification permission on first launch

---

## Updated Tab Order

```
Dashboard  |  Engines  |  Brokers  |  Positions  |  Logs  |  Trades  |  P&L  |  Alerts
   1              2           3            4           5        6         7        8
```

---

## File Structure — What to Add

```
AutoTraderIOS/
├── Networking/
│   ├── APIClient.swift          update — add X-API-Key, new v2 methods
│   ├── APIError.swift           (done)
│   └── KeychainHelper.swift     NEW
├── Models/
│   ├── ServerStatus.swift       (done — keep for legacy /status)
│   ├── Engine.swift             NEW — EngineHeartbeat
│   ├── BrokerHealth.swift       NEW
│   ├── LogsResponse.swift       update — add LogFile with compressed/log_date
│   ├── MTMResponse.swift        (done)
│   ├── TradesResponse.swift     (done)
│   └── ActionResponses.swift    update — add LaunchRequest/Response
├── ViewModels/
│   ├── AppState.swift           update — API key, healthDeep, engine list
│   ├── DashboardVM.swift        update — remove broker auth (move to BrokersVM)
│   ├── EnginesVM.swift          NEW (rename/replace TradeVM)
│   ├── BrokersVM.swift          NEW
│   ├── PositionsVM.swift        NEW
│   ├── LogsVM.swift             update — file list, date picker, broker API tab
│   ├── TradesVM.swift           (done)
│   ├── PnLVM.swift              NEW
│   └── AlertsVM.swift           NEW
├── Views/
│   ├── RootTabView.swift        update — add 4 new tabs
│   ├── Dashboard/               (done — remove broker section)
│   ├── Engines/
│   │   ├── EnginesView.swift    NEW (replaces TradeView)
│   │   └── LaunchSheet.swift    NEW
│   ├── Brokers/
│   │   └── BrokersView.swift    NEW
│   ├── Positions/
│   │   └── PositionsView.swift  NEW
│   ├── Logs/                    update — file picker, date picker, broker API tab
│   ├── Trades/                  (done)
│   ├── PnL/
│   │   └── PnLView.swift        NEW
│   ├── Alerts/
│   │   └── AlertsView.swift     NEW
│   └── Settings/                update — API key field + rotation
└── Helpers/
    └── ExpiryHelper.swift       NEW — weeklyExpiries() + fyersCode()
```

---

## Priority Order

| Priority | Task | Effort |
|----------|------|--------|
| 1 | X-API-Key auth (§1) | 0.5 day |
| 2 | APIClient v2 methods + new models (§2) | 1 day |
| 3 | Engines tab — engine list + launch sheet + expiry picker (§3) | 1.5 days |
| 4 | Brokers tab — split from Dashboard + Tradesmart (§4) | 0.5 day |
| 5 | Logs upgrade — file/date picker + broker API tab (§5) | 1 day |
| 6 | Positions tab — live MTM (§6) | 0.5 day |
| 7 | P&L tab — Charts (§7) | 0.5 day |
| 8 | Alerts tab (§8) | 0.5 day |
| 9 | Settings — key rotation (§9) | 0.5 day |
| 10 | Background notifications (§10) | 1 day |

**Total estimate: ~7–8 days**  
Items 1–5 are the meaningful gap vs the web dashboard. Items 6–10 are additive.
