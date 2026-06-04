# AutoTrader iOS — Novice‑First UX Redesign + Full API Integration Plan

> **Purpose of this doc.** A self‑contained, executable plan so any future session
> (including Claude mobile, after a session‑limit reset) can continue the work
> without re‑deriving context. It is committed to the repo on `develop`.
>
> **Read first:** `CLAUDE.md` (conventions), then this file. The backend is the
> source of truth: `~/Developer/Auto_Option/src/api_server.py` (present on the
> primary dev machine) and the live spec at
> `https://trader.allweatheralgo.com/openapi.json`.

---

## 0. Status snapshot (what is already done vs. pending)

### ✅ Done (committed alongside this doc — "API foundation")
Multi‑engine **mobile API v1** is integrated end‑to‑end (networking + a first‑pass
"Engines" tab). These files exist and the app **builds clean** (`BUILD SUCCEEDED`):

- `Networking/APIClient.swift` — 9 new methods + `X-API-Key` header injection + 401/503 mapping.
- `Networking/APIError.swift` — `.unauthorized`, `.serverKeyNotConfigured`.
- `Support/KeychainStore.swift` — Keychain store for the write key.
- `Support/JSONValue.swift` — type‑erased Codable for free‑form `params`/`config`.
- `Models/EngineModels.swift` — requests (snake_case CodingKeys) + responses (camelCase) + `EngineValidation`.
- `ViewModels/EnginesVM.swift` — list/detail/create VMs (`Loadable<T>`, de‑dupe, cancellation).
- `Views/Engines/*` — `EnginesListView`, `EngineDetailView`, `CreateEngineView`, `EngineStatusBadge`.
- `ViewModels/AppState.swift`, `Views/Settings/*` — Keychain `apiKey` + rotation UI.
- `AutoTraderIOSTests/MobileAPIContractTests.swift` — 11 contract tests (encode/decode + validation).
- `Views/RootTabView.swift` — Engines tab added (currently tab #2).

### ⛔ Pending (this plan) — the novice‑first redesign
The current screens are **engineer‑facing** (they say "engine", "X-API-Key",
"dry_run", "systemctl", "Iron Condor"). The target user is a **non‑technical
novice**. This plan reskins the IA, language, flows, and safety so a first‑timer
can connect → configure → run → monitor in < 5 minutes with no docs. The API
layer below stays; **only the presentation + workflow layer changes.**

> ⚠️ **Backward compatibility:** keep all existing `APIClient` methods and the
> legacy single‑engine endpoints working. The redesign is additive at the UI
> layer; do not delete the networking layer or break the decoder conventions.

---

## 1. API inventory & gap analysis (single source of truth)

Verified against `openapi.json` + backend source. **41 paths total.**

### 1A. Legacy single‑engine control (already in app)
| Endpoint | In app? | Notes |
|---|---|---|
| `GET /status` | ✅ | 5s poll via `AppState` |
| `GET /mtm` · `GET /trades` | ✅ | Positions tab |
| `GET /logs` · `GET /logs/api` · `POST /logs/clear` | ✅ | Logs tab |
| `GET /metrics` | ✅ | bandwidth buckets |
| `GET /margin/iron-condor` | ✅ | margin estimate |
| `POST /start/iron-condor` · `POST /start/vix-scalp` · `POST /stop` | ✅ | Trade tab |
| `POST /token/{fyers,kite,tradesmart/exchange}` · `POST /token/fyers/save-env` | ✅ | broker auth |
| `POST /start/trend-agent` · `POST /stop/trend-agent` · `GET /trend-agent/{status,signals,learning,trades,logs}` | ✅ | Trend tab |
| `GET /health` (hidden from schema, `include_in_schema=False`) | ✅ | Test Connection. **Not a bug** — exists server‑side. |

### 1B. Mobile API v1 — multi‑engine (networking ✅ done, UX ⛔ pending)
All under `/api/v1/`. **Writes require `X-API-Key`; GET reads are open.**
| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/engines` | open | List engines + heartbeat |
| POST | `/api/v1/engines` | key | Create (config YAML + secrets, opt. autostart) |
| GET | `/api/v1/engines/{id}/status` | open | One engine status |
| GET | `/api/v1/engines/{id}/config` | open | Read config |
| PATCH | `/api/v1/engines/{id}/config` | key | Merge‑update config |
| POST | `/api/v1/engines/{id}/start` | key | systemctl start |
| POST | `/api/v1/engines/{id}/stop` | key | systemctl stop |
| POST | `/api/v1/engines/{id}/restart` | key | systemctl restart |
| DELETE | `/api/v1/engines/{id}` | key | Remove config (secrets kept) |
| PUT | `/api/v1/config/api-key` | key | Rotate key (`{api_key}`, ≥12 chars) |
| PUT | `/api/v1/engines/{id}/token` | key | Update broker token |

**Request schemas** (authoritative): `CreateEngineRequest{engine_id*, broker* ∈ {fyers,kite,tradesmart}, strategy* ∈ {iron_condor,vix_scalp,trend}, params{}, access_token, telegram_bot_token, telegram_chat_id, autostart=false}`; `PatchEngineConfigRequest{params{}, extra{}}` (extra cannot override engine_id/broker/strategy); `EngineTokenRequest{access_token*}`; rotate `{api_key}`. `engine_id` regex `^[A-Za-z0-9_-]+$`.

**Response shapes** (spec says `{}`; from source): list→`{ok, engines:[{engine_id,broker,strategy,status:RUNNING|STALE|STOPPED,pid,last_beat,stale}]}`; create→`{ok,engine_id,config_path,secrets_path,autostarted,autostart_error?}`; config→`{ok,engine_id,config{}}`; lifecycle→`{ok,engine_id,status,unit}`; delete→`{ok,engine_id,status:"deleted",note}`; rotate→`{ok,updated_at,note}`.

### 1C. Server endpoints NOT yet used by the app (gap)
| Endpoint | Capability | Plan |
|---|---|---|
| `GET /scalping/mtm` | live P&L for VIX scalp | Fold into Activity → Positions |
| `POST /stop/vix-scalp` | stop only the scalp loop | Bot detail (when bot=Volatility) |
| `GET /logs/vix` | scalp logs | Logs filter |
| `GET /health/deep` | dependency health (broker/data/disk) | **Diagnostics screen + Home health pill** |
| `GET /metrics/app` | app‑level metrics | Diagnostics |
| `GET /engines` (legacy, non‑`/api/v1`) | older engine listing | Prefer `/api/v1/engines`; ignore unless needed |
| `GET /engines/{id}/logs` | per‑engine logs | Bot detail → Logs |

### 1D. Discrepancies / risks flagged
1. **No `X-API-Key` historically** → all mobile writes 401 without it. Resolved via Keychain store.
2. Mobile **responses are untyped** in OpenAPI (`{}`) — never trust the spec for them; read the Python handlers.
3. `engine_id` is filesystem‑namespaced; **mirror the regex client‑side** (done in `EngineValidation`) to avoid 400s.
4. Reads are **unauthenticated by design** (same‑trust private network). Surface this honestly; do not imply per‑user auth.
5. Two overlapping control planes (legacy `/start/*` vs `/api/v1/engines`). **For novices, expose only ONE mental model** ("Bots"); keep legacy under the hood / advanced.

---

## 2. Novice‑first product principles → concrete decisions

| Principle | Concrete decision in this app |
|---|---|
| Clarity over density | Reduce **6 tabs → 4** (Home, Bots, Activity, More). Hide advanced controls behind "Advanced" disclosure. |
| Plain language | Adopt the **glossary in §3**. "Engine"→"Bot", "dry_run"→"Practice mode", "X-API-Key"→"Admin access code", strategy code names→friendly names + subtitles. |
| Guided workflows | **Create‑a‑Bot wizard** (4 steps) + **first‑run onboarding** (4 steps). |
| Dashboard‑first | **Home** answers the 6 questions at a glance with one primary CTA. |
| Visual status | Single shared status system: Running / Starting / Stopping / Stopped / Not responding / Connected / Disconnected / Healthy / Warning / Error — color + SF Symbol + word. |
| Action‑oriented | Primary actions never more than 1 tap from Home. |
| Safety | Confirm + explain consequences for Start‑Live, Stop, Delete, Rotate key. Default everything to **Practice mode**. |
| Native iOS | SwiftUI, NavigationStack, TabView, List, Form, sheets, context menus, swipe, `.searchable`, `.refreshable`, `ContentUnavailableView`. |
| Explain every feature | Each screen has an info row / `(?)` popover: what / when / risk / outcome. |
| Empty states | Every list uses `ContentUnavailableView` with a "what next" CTA. |
| Error handling | Map `APIError` → friendly "what happened / why / fix / retry". Never show raw 500s or stack traces. |
| Accessibility | Dynamic Type, VoiceOver labels, ≥44pt targets, color‑independent status (icon+text), high contrast. |

---

## 3. Plain‑language glossary (apply everywhere — labels, a11y, help)

| Technical term | User‑facing label | One‑line help |
|---|---|---|
| Engine | **Bot** (a.k.a. "Auto‑Trader") | "A bot trades automatically using a strategy and your broker account." |
| Broker | **Broker (your trading account)** | "The account that actually places trades — e.g. Zerodha, Fyers." |
| Strategy | **Trading style** | "The rules the bot follows to decide trades." |
| `iron_condor` | **Range Income** | "Earns when the market stays calm and range‑bound." |
| `vix_scalp` | **Volatility Spike** | "Trades quick moves when the market gets jumpy." |
| `trend` | **Trend Follower** | "Rides sustained up or down moves." |
| `dry_run: true` | **Practice mode (no real money)** | "Simulates trades. Nothing real is bought or sold." |
| `dry_run: false` | **Live mode (real money)** | "Places real trades with real funds." |
| `X-API-Key` | **Admin access code** | "Unlocks making changes (creating/starting/stopping bots)." |
| `access_token` (broker) | **Broker login** | "Connects the bot to your broker. Expires daily — reconnect when asked." |
| systemctl start/stop/restart | **Start / Stop / Restart** | — |
| `STALE` / `stale:true` | **Not responding** | "The bot hasn't checked in recently. Try Restart." |
| heartbeat / `last_beat` | **Last seen** | — |
| MTM | **Live P&L** | "Profit or loss right now on open positions." |
| `/health/deep` | **System check** | "Confirms the server, broker, and data feed are all OK." |

---

## 4. Information architecture & navigation

### 4A. Tab structure (4 tabs)
```
TabView
├── Home        (house.fill)            → DashboardView (redesigned)
├── Bots        (server.rack)           → BotsListView → BotDetailView, CreateBotWizard
├── Activity    (chart.line.uptrend...) → ActivityView (Positions / Trades / Performance segments)
└── More        (ellipsis.circle)       → MoreMenu → Broker, Logs, Diagnostics, Settings, Help
```
Rationale: 4 tabs avoids the iOS "More" overflow (6 tabs collapses on compact
iPhone). Legacy Trade/Trend screens are **reachable but demoted** (Bots covers
their function; keep a "Manual / Advanced" entry under More for power users to
preserve backward compatibility).

### 4B. Navigation map
```
Home ──tap status card──────────────► Bots › BotDetail
 │   ──"Connect broker" alert───────► More › Broker
 │   ──"Fix issue" alert────────────► More › Diagnostics
 │   ──primary CTA (no bots)────────► CreateBotWizard (sheet)
 │
Bots ─＋──────────────────────────► CreateBotWizard (sheet, 4 steps)
 │   ──row tap──────────────────────► BotDetail (status, controls, settings, token)
 │   ──swipe / context menu─────────► Start / Stop / Restart / Delete (confirm)
 │
Activity ─segmented──► Positions | Trades | Performance
 │
More ──► Broker connect (Safari OAuth) · Logs (filter) · Diagnostics (system check)
         · Settings (server URL, Admin code, rotate) · Help / About
```

### 4C. User journey (first‑timer happy path)
```
Launch → Onboarding(4) → Home(empty) → "Create your first bot" →
Wizard: 1 Style → 2 Broker → 3 Name → 4 Review(Practice ON) → Create →
BotDetail → Start (Practice) → Home shows "Running • Practice" →
Activity shows simulated positions → user confident → later flips to Live (guarded).
```

---

## 5. Screen specs + wireframes

> Wireframes are ASCII for portability. Build with native components; apply
> `glassCard()`/`thinGlassCard()` per `Support/Theme.swift`.

### 5.1 Onboarding (first launch only; store `didOnboard` in UserDefaults)
4 paged steps, skippable, `TabView(.page)` or `NavigationStack`:
```
┌──────────────────────────────┐
│           👋  Welcome         │
│  AutoTrader runs trading      │
│  bots for you, automatically. │
│                              ● ○ ○ ○ │
│        [ Continue ]          │
└──────────────────────────────┘
 1 Welcome — what the app does (plain).
 2 Connect server — enter server URL + Admin access code (with "what's this?").
 3 Connect a broker — explain daily login; button → OAuth (can skip).
 4 You're set — "Create a bot any time. Everything starts in Practice mode."
```

### 5.2 Home / Dashboard (answers the 6 questions)
```
┌───────────────────────────────────────────┐
│  Good morning                      ⚙︎      │
│ ┌───────────────────────────────────────┐ │
│ │ ● Running · Practice                  │ │  ← status hero (color+icon+word)
│ │ Range Income · Zerodha                │ │
│ │ Up 2h 13m                  [ Stop ▢ ] │ │
│ └───────────────────────────────────────┘ │
│ ┌─────────────┐ ┌─────────────────────┐  │
│ │ Live P&L    │ │ Broker              │  │
│ │ +₹1,240 🟢  │ │ ✓ Connected (Zerodha)│ │
│ └─────────────┘ └─────────────────────┘  │
│ ┌───────────────────────────────────────┐ │
│ │ ⚠︎ 1 bot not responding — Restart?    │ │  ← alerts only when present
│ └───────────────────────────────────────┘ │
│  Quick actions:                            │
│  [▶ Start a bot] [＋ New bot] [📈 Activity]│
└───────────────────────────────────────────┘
```
- States: **no bots** → big CTA "Create your first bot"; **no broker** →
  "Connect a broker to trade live" (still allows Practice); **all healthy** → hide alerts.
- Data: `GET /api/v1/engines` (which bot is running), `GET /status`, `GET /mtm`,
  `GET /health/deep` (health pill). Pull‑to‑refresh + 5s poll while foregrounded.

### 5.3 Bots list
```
┌───────────────────────────────────────────┐
│  Bots                               ＋     │
│  🔍 Search                                 │
│ ┌───────────────────────────────────────┐ │
│ │ My Range Bot                ● Running │ │
│ │ Range Income · Zerodha · Practice     │ │
│ ├───────────────────────────────────────┤ │
│ │ Scalper                     ◦ Stopped │ │
│ │ Volatility Spike · Fyers              │ │
│ └───────────────────────────────────────┘ │
│  swipe → Start/Stop · context → Restart/Delete │
└───────────────────────────────────────────┘
```
- Empty: `ContentUnavailableView("No bots yet", systemImage:"server.rack", desc + "Create your first bot")`.
- If no Admin code: rows are read‑only; tapping ＋ shows a sheet "Add your Admin access code in Settings to create bots." (Reuse `appState.hasAPIKey`.)

### 5.4 Create‑a‑Bot wizard (sheet, 4 steps, progress dots)
```
Step 1 Style:   cards → Range Income / Volatility Spike / Trend Follower
                each card: friendly name + 1‑line + risk chip (Lower/Higher)
Step 2 Broker:  picker (only brokers the user has connected highlighted);
                "Connect a new broker" link → OAuth.
Step 3 Name:    text field "Give your bot a name" → maps to engine_id
                (auto‑slugify to ^[A-Za-z0-9_-]+$; show the cleaned id subtly).
Step 4 Review:  summary + big toggle PRACTICE (default ON).
                If user flips to LIVE → inline red warning + confirm.
                [ Create bot ]  → POST /api/v1/engines (params:{dry_run})
                                   optional "Start now" toggle = autostart.
```
- Validation surfaced inline, friendly ("Names can use letters, numbers, - and _").
- Success → dismiss → navigate to BotDetail → toast "Bot created (Practice mode)".

### 5.5 Bot detail
```
┌───────────────────────────────────────────┐
│  My Range Bot                              │
│  ● Running · Practice            Last seen 3s│
│  [ ▶ Start ]  [ ⟳ Restart ]  [ ▢ Stop ]    │  (disabled w/o Admin code)
│  ───────────────────────────────────────── │
│  Settings                                   │
│   Practice mode            [  ON  ]  (PATCH)│
│   Broker login             Update ›         │
│  ▸ Advanced (raw config)   (disclosure)     │
│  ───────────────────────────────────────── │
│  This bot                                   │
│   Style: Range Income (what it does…)       │
│   Broker: Zerodha                           │
│  [ Delete bot ]  (destructive, confirm)     │
└───────────────────────────────────────────┘
```
- Practice toggle → `PATCH config {params:{dry_run}}`; show "Restart to apply".
- "Update broker login" sheet → `PUT …/token`.
- Advanced disclosure renders `GET …/config` via `JSONValue` rows (read‑only for novices).

### 5.6 Activity (segmented: Positions / Trades / Performance)
- Positions: `MTMCard` + `/mtm` (+ `/scalping/mtm` when a Volatility bot runs). Each row plain: symbol, qty, P&L colored.
- Trades: `/trades` history cards.
- Performance: `/metrics` simplified into "Data sent today" etc.; charts via Swift Charts. Empty → "No activity yet. Start a bot to see results."

### 5.7 More → Broker / Logs / Diagnostics / Settings / Help
- **Broker:** connection cards per broker (Connected ✓ / Reconnect), OAuth via `SFSafariViewController`; explain daily expiry.
- **Logs:** `.searchable` + filter (Engine / API / Scalp via `/logs`, `/logs/api`, `/logs/vix`); "Clear" with confirm. Plain empty state.
- **Diagnostics:** "Run system check" → `GET /health/deep` + `/metrics/app`; render each dependency as Healthy/Warning/Error with fix hints. This is the novice‑safe place for raw detail.
- **Settings:** server URL; **Admin access code** (Keychain, SecureField) with "what's this?"; Rotate code (guarded); appearance; version.
- **Help/About:** short "How it works", glossary, safety notes.

### 5.8 Shared status component
`enum AppStatus { running, starting, stopping, stopped, notResponding, connected, disconnected, healthy, warning, error }`
→ `StatusChip` (color + SF Symbol + word) reused on Home, Bots, BotDetail, Broker, Diagnostics. **Never color‑only** (a11y).

---

## 6. Error & empty‑state mapping (build a `FriendlyError` layer)

Map `APIError` → `{title, message, fix, retry?}`:
| APIError | Title | Message → Fix |
|---|---|---|
| `.noNetwork` | "Can't reach the server" | "Check your internet / the server, then retry." (retry) |
| `.timeout` | "Taking too long" | "The server may be waking up. Try again." (retry) |
| `.wrongBaseURL` | "Server address looks wrong" | "Check the address in Settings." (→Settings) |
| `.unauthorized` (401) | "Admin code needed" | "Add or fix your Admin access code in Settings." (→Settings) |
| `.serverKeyNotConfigured` (503) | "Server isn't set up for changes" | "The server has no admin code configured. Contact the server owner." |
| `.engineAlreadyRunning` (409) | "Already running" | "Stop it first, or pick another bot." |
| `.validationError` (422) | "Check your entries" | show field msgs in plain form. |
| `.httpError ≥500` | "Server hiccup" | "Something went wrong on the server. Try again shortly." (retry) |
| `.decodingError` | "Unexpected response" | "The app couldn't read the server's reply. Update the app or retry." |

Empty states (all `ContentUnavailableView`): no bots, no positions, no trades, no
logs, no broker connected, search‑no‑results. Each names **why** + **what next**.

---

## 7. Observability (Phase 7)

- **Structured logging:** keep `os.Logger(subsystem:"com.autotrader.ios", category:…)`. Add categories: `UI`, `Engines`, `Auth`. Redact tokens/keys in logs.
- **API request tracing:** add a lightweight signpost per request (`OSSignposter`) around `APIClient.perform` with method+path+status+ms; gated to DEBUG/TestFlight.
- **Analytics events (privacy‑safe, local or opt‑in):** `bot_created`, `bot_started{mode}`, `bot_stopped`, `broker_connected`, `error_shown{type}`, `onboarding_completed`. Define an `AnalyticsClient` protocol with a no‑op default (DI‑friendly; no third‑party SDK required).
- **Error reporting / crash diagnostics:** wire `MetricKit` (`MXMetricManager`) for crash + hang diagnostics with no external dependency; optionally add a crash reporter later behind the same protocol.
- **Performance metrics:** record request durations from the tracer; surface aggregate in Diagnostics.

---

## 8. Robustness (Phase 8)

- **No race conditions:** all VMs `@MainActor`; state mutated only on main.
- **No duplicate calls / idempotency:** per‑action in‑flight guards (`busy` sets, `busyAction`) already in `EnginesVM`; extend to all mutating actions. Lifecycle start/stop/restart are server‑idempotent (systemctl) — safe to retry.
- **Task cancellation:** keep `loadTask?.cancel()` pattern; cancel on `.onDisappear`; use `.task{}` (auto‑cancels) for view‑scoped loads.
- **Retry with backoff:** add a `retry(times:backoff:)` helper for **idempotent GETs only** (status/list/health), exponential 0.5→1→2s, max 3; never auto‑retry writes.
- **Offline handling:** `NWPathMonitor` → `AppState.isOnline`; show a `ConnectionBanner`; disable mutating buttons offline with explanation.
- **Thread‑safe key storage:** Keychain access is already serial; never cache the key in plaintext beyond `AppState.apiKey`.

---

## 9. Testing strategy (Phase 9)

> ⚠️ This environment has **no installed simulator runtime** — `build-for-testing`
> compiles but tests can't *run* here. On a machine with a simulator:
> `xcodebuild test -scheme AutoTraderIOS -destination 'platform=iOS Simulator,name=iPhone 16'`.

- **Contract tests (exist, extend):** `MobileAPIContractTests` — keep one per request/response model; add the new friendly‑error mapping + slugify(name→engine_id).
- **Unit tests:** VMs with a mocked `APIClient` (introduce an `EnginesService` protocol for DI — see §10). Cover: load success/empty/failure, start/stop de‑dupe, create validation, practice‑toggle PATCH, token update, rotate.
- **Integration tests:** against a stub `URLProtocol` returning canned JSON for each endpoint; assert decode + state transitions.
- **UI tests:** onboarding completes; create‑bot wizard happy path; start in Practice; error alert appears on 401; empty states render.
- **Regression plan:** smoke list = launch, onboarding, create bot (practice), start, stop, delete, broker connect, view positions, view logs, run system check, rotate key. Run before each release.

---

## 10. Architecture / tech‑debt improvements to do first

1. **Introduce a service protocol for DI/testability.** `APIClient` is a concrete
   struct used directly by VMs. Add `protocol EngineService` (and optionally
   `TradingService`) that `APIClient` conforms to; inject via init so VMs are unit‑testable with mocks. (Backward compatible — keep concrete usage working.)
2. **Centralize friendly‑error mapping** (`FriendlyError`) so every screen renders consistently.
3. **Shared `StatusChip` + `AppStatus`** to unify the 9 visual states.
4. **`Loadable<T>`** (already added) — adopt across existing tabs for consistent loading/empty/error.
5. **Feature‑folder modularization:** `Features/{Home,Bots,Activity,Broker,Diagnostics,Settings,Onboarding}` each with View+VM; shared in `Support/`, `Components/`, `Networking/`, `Models/`.
6. Keep the **decoder conventions** (CLAUDE.md) — do not add snake_case CodingKeys to Decodable models.

---

## 11. Task breakdown (executable checklist)

> Order chosen so each milestone leaves the app shippable. Check items off as you go.

### Milestone A — Foundations (no visible change)
- [x] Add `protocol EngineService`; conform `APIClient`; inject into `EnginesVM`/detail/create.
- [x] Add `FriendlyError` mapping + unit tests.
- [x] Add `AppStatus` + `StatusChip` component (color+icon+text, a11y labels).
- [x] Add `NWPathMonitor` → `AppState.isOnline`; wire `ConnectionBanner`.
- [x] Add request tracer (`OSSignposter`) + `AnalyticsClient` no‑op protocol.

### Milestone B — IA & navigation
- [x] Rebuild `RootTabView` to 4 tabs (Home, Bots, Activity, More). Move legacy Trade/Trend under More → "Manual / Advanced".
- [x] Add `OnboardingView` (4 pages) gated by `didOnboard` UserDefaults flag.

### Milestone C — Home dashboard
- [x] `HomeViewModel` aggregating `/api/v1/engines` + `/status` + `/mtm` + `/health/deep`.
- [x] Status hero card, P&L card, Broker card, alerts, quick actions, empty/no‑broker states.

### Milestone D — Bots (reskin existing Engines)
- [x] Rename UI surface Engine→Bot; apply glossary to all labels + a11y + help popovers.
- [x] `CreateBotWizard` (4 steps) replacing the single `CreateEngineView` form; slugify name→engine_id.
- [x] BotDetail: practice toggle (PATCH), broker‑login update (PUT), Advanced config disclosure, delete (confirm).
- [x] Search + empty + no‑Admin‑code states.

### Milestone E — Activity
- [x] `ActivityView` segmented (Positions/Trades/Performance); wire `/mtm`, `/scalping/mtm`, `/trades`, `/metrics`; empty states.

### Milestone F — More
- [x] Broker connect screen (reuses DashboardView under More) (OAuth, daily‑expiry help).
- [x] Logs source filter (Engine/API/Scalp) + clear confirm + source filter (`/logs`, `/logs/api`, `/logs/vix`) + clear confirm.
- [x] Diagnostics: `/health/deep` + `/metrics/app` rendered as health rows with fixes.
- [x] Settings: server URL + Admin code (Keychain) + rotate (guarded) + appearance + version + help link.

### Milestone G — Safety, a11y, polish
- [x] Confirm dialogs w/ consequence text for Start‑Live, Stop, Delete, Rotate, Clear logs.
- [ ] Dynamic Type pass, VoiceOver labels, ≥44pt targets, contrast check, reduce‑motion.
- [x] Loading skeletons / spinners consistent via `Loadable<T>`.

### Milestone H — Tests & release
- [ ] Unit + integration (URLProtocol stub) + UI tests per §9.
- [ ] Run regression smoke list; update `CLAUDE.md`; TestFlight build.

---

## 12. Risk assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Novice starts a **Live** bot by accident | Med | High (real money) | Default Practice; flip‑to‑Live requires explicit confirm + red warning; Home badges "Live". |
| Admin code leaks (screenshots/logs) | Low | High | Keychain only; SecureField; redact in logs; never in analytics. |
| Reads are unauthenticated | — | Med | Document honestly; advise private network; don't imply per‑user security. |
| Broker token daily expiry confuses users | High | Med | Proactive "Reconnect broker" prompt on Home when status shows expired. |
| 6→4 tab migration hides features power users rely on | Med | Low | Keep legacy under More → Advanced; backward‑compatible. |
| Untyped mobile responses change server‑side | Med | Med | Contract tests + read handlers; defensive optional decoding. |
| No simulator in CI here | High | Low | Compile via `build-for-testing`; run tests on a sim‑equipped machine. |

---

## 13. Migration & backward compatibility

- **Additive, not destructive.** Networking layer + decoder conventions unchanged.
- Legacy single‑engine screens (Trade, Trend) remain reachable under **More → Advanced** so nothing is lost while the Bot model becomes the primary path.
- Persisted keys unchanged (`serverBaseURL` in UserDefaults; Admin code in Keychain).
- Ship behind milestones; each is independently shippable. No server changes required.

---

## 14. Production readiness checklist

- [x] All 41 endpoints reviewed; every one mapped to a screen or explicitly deferred (§1).
- [x] Every screen: states for loading / loaded / empty / error.
- [x] No raw technical errors surfaced (FriendlyError everywhere).
- [x] Dangerous actions confirmed with consequence text.
- [x] Default to Practice; Live clearly badged.
- [ ] Dynamic Type + VoiceOver + contrast verified on Home, Bots, BotDetail, Wizard.
- [x] Offline banner + disabled mutations offline.
- [x] Tokens/keys never logged; Keychain‑only.
- [ ] Unit + integration + UI + contract tests green on a sim machine; regression smoke passed.
- [x] `CLAUDE.md` updated; memory updated.
- [ ] First‑run user test: connect → configure → start (Practice) → monitor in < 5 min, no docs.

---

## 15. How to resume from a fresh session (incl. Claude mobile)

1. Read `CLAUDE.md`, then this file.
2. Confirm the API foundation still builds:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme AutoTraderIOS -destination 'generic/platform=iOS Simulator' -configuration Debug build`
3. Start at **§11 Milestone A** and work down; keep each milestone shippable.
4. Source of truth for shapes: `~/Developer/Auto_Option/src/api_server.py` + live `openapi.json`. Don't assume payloads.
5. Honor decoder conventions and the glossary. Reskin, don't rewrite, the networking layer.
