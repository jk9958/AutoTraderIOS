# Spec: one-tap broker reconnect for any broker (`token/sync`)

> **Status:** ✅ implemented (backend live; iOS client wired 2026-06-05).
> **Backend repo:** `Auto_Option` (`src/api_server.py`). **Client repo:** AutoTraderIOS.
>
> iOS: `APIClient.syncEngineToken` + `EngineServicing`; 409 → `APIError.brokerNotConnected`
> (friendly "Finish the broker login"); `EngineDetailView` reconnect is now
> broker-agnostic (open broker OAuth → `token/sync`, no token over the wire), with
> manual paste kept as a fallback.

## 1. Problem & goal

A mobile-API bot reads its **own** `secrets/<engine_id>.env`. Broker OAuth, however,
refreshes the **server's main** token (writes the project `.env` + `os.environ` via
`_update_env_key`). Today the iOS app bridges this only for **Fyers**, because Fyers
is the one broker whose raw token is exposed back to the client (`/status.fyers_access_token`),
so the app can read it and `PUT …/token`. Kite and TradeSmart don't expose their raw
token, so they're stuck on manual paste.

**Goal:** a single server endpoint that copies the **current main token for the bot's
broker** into that bot's secrets file, server-side, so the raw token never crosses the
wire and **all three brokers** get the same one-tap reconnect.

## 2. Why this is now possible (verified facts)

- `_update_env_key(key, value)` sets the project `.env` **and** `os.environ[key]`
  (`src/api_server.py`). So after each broker's auth flow the live token sits in:
  | broker | env var (`_BROKER_TOKEN_KEY`) | populated by |
  |---|---|---|
  | fyers | `FYERS_ACCESS_TOKEN` | `/auth/fyers/callback`, `/token/fyers`, `/token/fyers/save-env` |
  | kite | `ACCESS_TOKEN` | `/token/kite` |
  | tradesmart | `TS_SUSERTOKEN` | `/auth/tradesmart/callback` / `/token/tradesmart/exchange` ⚠️ **prerequisite, see §7** |
- The existing `PUT /api/v1/engines/{id}/token` already resolves an engine → its broker
  (from `config/<id>.yaml`) → `token_key`, then rewrites `secrets/<id>.env`. The sync
  endpoint reuses that write path with the value sourced from `os.environ[token_key]`.

## 3. Endpoint contract

```
POST /api/v1/engines/{engine_id}/token/sync
```
| | |
|---|---|
| **Auth** | `X-API-Key` header (write endpoint; `Depends(_require_api_key)`) |
| **Path param** | `engine_id` — validated by `validate_engine_id` (`^[A-Za-z0-9_-]+$`) |
| **Query / body** | none (empty body) |
| **Tag** | `mobile` |
| **Idempotent** | yes (re-running with the same env token is a no-op rewrite) |

### Success — `200`
```json
{
  "ok": true,
  "engine_id": "engine_kite_01",
  "broker": "kite",
  "token_key": "ACCESS_TOKEN",
  "updated_at": "14:32",
  "source": "server-env"
}
```

### Errors (FastAPI `{ "detail": "…" }`)
| Code | When | `detail` example |
|---|---|---|
| `400` | invalid `engine_id` | "Invalid engine_id …" |
| `404` | no `config/<id>.yaml` | "No config for engine 'x'" |
| `409` | server has no token for that broker yet (env var empty/missing) | "No kite login on the server yet — connect the broker first." |
| `401` | bad/missing `X-API-Key` | "Invalid or missing X-API-Key header" |
| `503` | `API_KEY` not set on server | "API_KEY not set on server …" |

> `409` is the meaningful new case: the user must complete the broker's web login
> first (which populates the env var), then sync. The iOS flow does both in sequence.

## 4. Server implementation sketch

Refactor the secrets-write out of the existing PUT handler into a shared helper, then
add the sync handler. No behaviour change to the existing endpoint.

```python
def _write_engine_token(engine_id: str, token: str) -> dict:
    """Write `token` into secrets/<engine_id>.env under the engine's broker token key."""
    broker = "fyers"
    cfg_path = _PROJECT_ROOT / "config" / f"{engine_id}.yaml"
    if not cfg_path.exists():
        raise HTTPException(404, f"No config for engine {engine_id!r}")
    raw = _yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    broker = raw.get("broker", "fyers")
    token_key = _BROKER_TOKEN_KEY.get(broker, "FYERS_ACCESS_TOKEN")

    sec_path = _PROJECT_ROOT / "secrets" / f"{engine_id}.env"
    sec_path.parent.mkdir(exist_ok=True)
    # ... existing line-rewrite logic, writing f"{token_key}={token}\n" ...
    try: sec_path.chmod(0o600)
    except Exception: pass
    return {"broker": broker, "token_key": token_key}


@app.post("/api/v1/engines/{engine_id}/token/sync",
          tags=["mobile"], dependencies=[Depends(_require_api_key)])
def api_sync_engine_token(engine_id: str):
    """Copy the server's current broker token into this engine's secrets.
    No token is sent by the client — the value is read from the server env."""
    from src.engine_paths import validate_engine_id
    try:
        validate_engine_id(engine_id)
    except ValueError as exc:
        raise HTTPException(400, str(exc))

    # Resolve broker → token_key from the engine config
    cfg_path = _PROJECT_ROOT / "config" / f"{engine_id}.yaml"
    if not cfg_path.exists():
        raise HTTPException(404, f"No config for engine {engine_id!r}")
    raw = _yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    broker = raw.get("broker", "fyers")
    token_key = _BROKER_TOKEN_KEY.get(broker, "FYERS_ACCESS_TOKEN")

    token = os.environ.get(token_key, "").strip()
    if not token:
        raise HTTPException(409,
            f"No {broker} login on the server yet — connect the broker first.")

    info = _write_engine_token(engine_id, token)
    ts = _now_ist().strftime("%H:%M")
    return {"ok": True, "engine_id": engine_id, "broker": info["broker"],
            "token_key": info["token_key"], "updated_at": ts, "source": "server-env"}
```

The existing `api_update_engine_token` (manual paste) should be refactored to call
`_write_engine_token(engine_id, req.access_token)` so both paths share one writer.

## 5. Security

- Same trust model as the rest of the mobile API: **write endpoint, requires `X-API-Key`**;
  reads stay open.
- **No secret material in the request or response.** The response returns only the
  `token_key` *name* and a timestamp — never the token value. (Contrast with today's
  Fyers flow, which sends the raw token from `/status` back through the client.) This
  endpoint is strictly **more** secure and lets us stop exposing `fyers_access_token`
  client-side later if desired.
- Secrets file is `chmod 600`, unchanged.

## 6. iOS client changes

Small, and they let the app drop the Fyers-specific token read.

1. **`APIClient`** — add:
   ```swift
   func syncEngineToken(_ engineId: String) async throws -> EngineActionResponse {
       let path = "/api/v1/engines/\(Self.escape(engineId))/token/sync"
       var req = try urlRequest(path, method: "POST", timeout: Self.actionTimeout)
       req.httpBody = Data()
       let (data, response) = try await perform(req)
       try validate(response, data: data)
       return try decode(EngineActionResponse.self, from: data)
   }
   ```
   Add `func syncEngineToken(_:) async throws -> EngineActionResponse` to the
   `EngineServicing` protocol too.

2. **`APIError` / `validate()`** — map `409` here to a friendly "Connect the broker
   first" message in `FriendlyError` (currently 409 → `engineAlreadyRunning`, which is
   wrong for this path; either branch on `detail`, or have the client treat the sync
   `409` specially).

3. **`EngineDetailView`** — make reconnect broker-agnostic. Replace the Fyers-only
   branch with, for **any** broker:
   1. Open that broker's web login: `fyersAuthURL()` / `kiteAuthURL()` / `tradesmartAuthURL()`.
   2. On Safari dismiss → `try await client.syncEngineToken(engineId)`.
   3. On success → `enginesStore.invalidate(id)`, show "Reconnected — restart the bot."
   4. On `409` → "Finish the broker login, then try again."

   The `fyers_access_token` read and the per-broker manual-paste fallback can be removed
   (keep paste only as a hidden "Advanced" affordance if you like).

## 7. Prerequisite to verify before shipping

Confirm the **TradeSmart** auth path writes `TS_SUSERTOKEN` to the environment (i.e.
calls `_update_env_key("TS_SUSERTOKEN", token)` in `/auth/tradesmart/callback` and/or
`/token/tradesmart/exchange`). Fyers (`FYERS_ACCESS_TOKEN`) and Kite (`ACCESS_TOKEN`)
are confirmed. If TradeSmart only sets `_token_status` without the env var, add the
`_update_env_key` call — one line — otherwise `token/sync` will `409` for TradeSmart bots.

## 8. Testing

- **Backend unit:** create a temp engine config (`broker: kite`), set `os.environ["ACCESS_TOKEN"]`,
  call the handler, assert `secrets/<id>.env` contains `ACCESS_TOKEN=…`; assert `409`
  when the env var is empty; `404` when no config; `401` without key.
- **iOS contract test:** decode a sample `200` into `EngineActionResponse`
  (`ok/engineId/broker/updatedAt`), and assert the `409`→friendly mapping.
- **Manual:** Kite bot → Reconnect → Kite login → returns → bot shows updated; restart → trades.

## 9. Backward compatibility

Purely additive. The existing `PUT …/token` (manual paste) stays for power users and
as the Kite/TradeSmart fallback until this lands. No client is broken by adding the
endpoint; the iOS change is gated on the endpoint existing (feature-detect via a
`404`/`405` fallback to the current Fyers-only flow if you want a phased rollout).
