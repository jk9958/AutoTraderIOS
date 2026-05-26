"""
Live Iron Condor execution engine for NIFTY / SENSEX options.

Designed for Fyers broker; works with any client that implements:
  get_ltp(symbol, exchange) → float
  place_market_order(tradingsymbol, quantity, transaction_type, exchange) → dict
  place_limit_order(tradingsymbol, quantity, transaction_type, price, exchange) → dict
  cancel_order(order_id) → dict
  get_order_status(order_id) → dict | None

Execution flow per 15-minute cycle
------------------------------------
  run_cycle(now) is called by the external scheduler every 15 minutes.

  No position:
    If entry_start ≤ now ≤ entry_cutoff → fetch spot → compute strikes →
    fetch live quotes → place 4 entry orders → record position.

  Open position (checked in priority order):
    HARD_STOP     : spot ≥ short_ce  OR  spot ≤ short_pe  → exit immediately
    EOD           : now.time() ≥ eod_exit_time (default 15:15) → exit
    PROFIT_TARGET : cost_to_close ≤ credit × (1 − profit_target_pct) → exit
    SL            : cost_to_close ≥ credit × (1 + sl_multiplier)     → exit

Order sequencing
----------------
  Entry  : buy long wings first (caps max risk), then sell short strikes
  Exit   : market orders (speed over price) in reverse

State persistence
-----------------
  Position JSON saved to {state_dir}/iron_condor_state.json after every
  state change so the engine survives a crash/restart within the same day.

Trade log
---------
  Each closed trade appended as a CSV row to {log_dir}/iron_condor_trades.csv.

Fyers symbol format
-------------------
  Monthly: NFO:NIFTY29MAY2524000CE
  Weekly : NFO:NIFTY2552924000CE  (YY + single-digit-month + DD)
  Pass the expiry portion as --expiry when running.
"""
from __future__ import annotations

import csv
import json
import logging
import time
from dataclasses import asdict, dataclass
from datetime import date, datetime, time as dtime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

MARKET_OPEN  = dtime(9, 15)
MARKET_CLOSE = dtime(15, 30)


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class CondorPosition:
    """State of an open (or recently closed) iron condor."""
    entry_date:         str    # YYYY-MM-DD
    entry_time:         str    # ISO datetime
    entry_spot:         float
    atm:                int
    short_ce:           int
    long_ce:            int
    short_pe:           int
    long_pe:            int
    short_ce_sym:       str
    long_ce_sym:        str
    short_pe_sym:       str
    long_pe_sym:        str
    short_ce_entry_px:  float
    long_ce_entry_px:   float
    short_pe_entry_px:  float
    long_pe_entry_px:   float
    net_credit:         float   # points per unit
    profit_target_pts:  float   # cost_to_close ≤ this → take profit
    sl_pts:             float   # cost_to_close ≥ this → stop loss
    lots:               int
    lot_size:           int
    status:             str = "open"   # "open" | "closed"

    @property
    def total_units(self) -> int:
        return self.lots * self.lot_size

    @property
    def net_credit_rupees(self) -> float:
        return self.net_credit * self.total_units


@dataclass
class TradeRecord:
    """One completed iron condor trade."""
    entry_date:    str
    entry_time:    str
    exit_time:     str
    exit_reason:   str       # HARD_STOP | SL | PROFIT_TARGET | EOD
    entry_spot:    float
    exit_spot:     float
    atm:           int
    short_ce:      int
    long_ce:       int
    short_pe:      int
    long_pe:       int
    net_credit:    float
    cost_to_close: float
    pnl_points:    float
    pnl_rupees:    float
    lots:          int


# ---------------------------------------------------------------------------
# Engine
# ---------------------------------------------------------------------------

class IronCondorLiveEngine:
    """
    Manages one iron condor per trading day via live broker API.

    Parameters
    ----------
    broker            : authenticated broker client (FyersClient or compatible)
    symbol            : underlying, e.g. "NIFTY" or "SENSEX"
    expiry            : expiry portion of the option symbol, e.g. "29MAY25"
    exchange          : exchange for option orders, e.g. "NFO"
    spot_symbol       : full broker symbol for the index quote, e.g. "NSE:NIFTY50-INDEX"
    lot_size          : units per lot (25 for NIFTY, 20 for SENSEX)
    lots              : number of lots to trade per condor
    spread_pts        : OTM distance from ATM to each short strike (default 400)
    wing_pts          : additional distance from short to long (wing) strike (default 200)
    strike_interval   : strike rounding step — 100 for NIFTY / SENSEX
    profit_target_pct : exit when cost_to_close ≤ credit × (1 − pct) (default 0.50)
    sl_multiplier     : exit when cost_to_close ≥ credit × (1 + mult) (default 1.0)
    entry_start       : earliest time to enter (default 09:30)
    entry_cutoff      : latest time to initiate a new entry (default 11:00)
    eod_exit_time     : force-close time (default 15:15)
    fill_timeout_sec  : seconds to wait for a limit fill before market fallback (default 30)
    state_dir         : directory for crash-recovery state JSON (default "live_state")
    log_dir           : directory for trade CSV log (default "live_logs")
    dry_run           : if True, log orders without placing them (default False)
    """

    def __init__(
        self,
        broker,
        symbol:            str   = "NIFTY",
        expiry:            str   = "",
        exchange:          str   = "NFO",
        spot_symbol:       str   = "NSE:NIFTY50-INDEX",
        lot_size:          int   = 25,
        lots:              int   = 1,
        spread_pts:        int   = 400,
        wing_pts:          int   = 200,
        strike_interval:   int   = 100,
        profit_target_pct: float = 0.50,
        sl_multiplier:     float = 1.0,
        entry_start:       dtime = dtime(9, 30),
        entry_cutoff:      dtime = dtime(11, 0),
        eod_exit_time:     dtime = dtime(15, 15),
        fill_timeout_sec:  int   = 30,
        state_dir:         str   = "live_state",
        log_dir:           str   = "live_logs",
        dry_run:           bool  = False,
    ) -> None:
        if not expiry:
            raise ValueError(
                "expiry must be provided (e.g. '29MAY25' for monthly or '250529' for weekly). "
                "Verify the exact format from your broker's option chain."
            )

        self.broker            = broker
        self.symbol            = symbol
        self.expiry            = expiry
        self.exchange          = exchange
        self.spot_symbol       = spot_symbol
        self.lot_size          = lot_size
        self.lots              = lots
        self.spread_pts        = spread_pts
        self.wing_pts          = wing_pts
        self.strike_interval   = strike_interval
        self.profit_target_pct = profit_target_pct
        self.sl_multiplier     = sl_multiplier
        self.entry_start       = entry_start
        self.entry_cutoff      = entry_cutoff
        self.eod_exit_time     = eod_exit_time
        self.fill_timeout_sec  = fill_timeout_sec
        self.state_dir         = Path(state_dir)
        self.log_dir           = Path(log_dir)
        self.dry_run           = dry_run

        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.log_dir.mkdir(parents=True, exist_ok=True)

        self._position: Optional[CondorPosition] = None
        self._load_state()

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    def run_cycle(self, now: Optional[datetime] = None) -> None:
        """
        Call once per 15-minute candle close during market hours.
        The runner calls this at each 15-min boundary; it is a no-op outside
        market hours.
        """
        if now is None:
            now = datetime.now()

        t = now.time()
        if t < MARKET_OPEN or t > MARKET_CLOSE:
            return

        # Clear stale position from a prior trading day
        if self._position and self._position.entry_date != now.date().isoformat():
            logger.info("New trading day — resetting position state.")
            self._position = None
            self._save_state()

        if self._position is None or self._position.status == "closed":
            if self._position is None and self.entry_start <= t <= self.entry_cutoff:
                self._try_entry(now)
        else:
            self._monitor_exits(now)

    def status_line(self) -> str:
        """One-line summary of current state — useful for log tailing."""
        if self._position is None:
            return "no position today"
        pos = self._position
        if pos.status == "closed":
            return f"position closed for today"
        return (
            f"OPEN  [{pos.short_pe}P / {pos.short_ce}C]  "
            f"credit={pos.net_credit:.1f}  "
            f"target≤{pos.profit_target_pts:.1f}  sl≥{pos.sl_pts:.1f}  "
            f"lots={pos.lots}"
        )

    # ------------------------------------------------------------------
    # Entry
    # ------------------------------------------------------------------

    def _try_entry(self, now: datetime) -> None:
        spot = self._get_spot()
        if spot <= 0:
            logger.warning("Spot price unavailable — skipping entry this cycle")
            return

        si       = self.strike_interval
        atm      = round(spot / si) * si
        short_ce = atm + self.spread_pts
        long_ce  = short_ce + self.wing_pts
        short_pe = atm - self.spread_pts
        long_pe  = short_pe - self.wing_pts

        syms = {
            "short_ce": self._opt_sym(short_ce, "CE"),
            "long_ce":  self._opt_sym(long_ce,  "CE"),
            "short_pe": self._opt_sym(short_pe, "PE"),
            "long_pe":  self._opt_sym(long_pe,  "PE"),
        }

        quotes = self._fetch_quotes(list(syms.values()))
        px = {k: quotes.get(v, 0.0) for k, v in syms.items()}

        if any(p <= 0 for p in px.values()):
            logger.warning(f"Zero/invalid quotes {px} — skipping entry")
            return

        net_credit = (px["short_ce"] - px["long_ce"]) + (px["short_pe"] - px["long_pe"])
        if net_credit <= 0:
            logger.warning(f"net_credit={net_credit:.2f} ≤ 0 — strikes too far OTM, skipping")
            return

        logger.info(
            f"ENTRY  spot={spot:.0f}  ATM={atm}  "
            f"spread=[{long_pe}/{short_pe} | {short_ce}/{long_ce}]  "
            f"credit={net_credit:.1f} pts  lots={self.lots}  "
            f"{'[DRY RUN]' if self.dry_run else '[LIVE]'}"
        )

        qty = self.lots * self.lot_size

        # Buy wings first to cap max risk before selling short strikes
        self._place_orders([
            (syms["long_ce"],  qty, "BUY",  px["long_ce"]),
            (syms["long_pe"],  qty, "BUY",  px["long_pe"]),
            (syms["short_ce"], qty, "SELL", px["short_ce"]),
            (syms["short_pe"], qty, "SELL", px["short_pe"]),
        ], tag="ENTRY")

        self._position = CondorPosition(
            entry_date        = now.date().isoformat(),
            entry_time        = now.isoformat(),
            entry_spot        = spot,
            atm               = atm,
            short_ce          = short_ce,
            long_ce           = long_ce,
            short_pe          = short_pe,
            long_pe           = long_pe,
            short_ce_sym      = syms["short_ce"],
            long_ce_sym       = syms["long_ce"],
            short_pe_sym      = syms["short_pe"],
            long_pe_sym       = syms["long_pe"],
            short_ce_entry_px = px["short_ce"],
            long_ce_entry_px  = px["long_ce"],
            short_pe_entry_px = px["short_pe"],
            long_pe_entry_px  = px["long_pe"],
            net_credit        = round(net_credit, 2),
            profit_target_pts = round(net_credit * (1 - self.profit_target_pct), 2),
            sl_pts            = round(net_credit * (1 + self.sl_multiplier), 2),
            lots              = self.lots,
            lot_size          = self.lot_size,
        )
        self._save_state()
        if self.dry_run:
            self._log_dry_run_entry(self._position, px)
        logger.info(
            f"Position recorded: credit={net_credit:.2f}  "
            f"target≤{self._position.profit_target_pts:.2f}  "
            f"sl≥{self._position.sl_pts:.2f}  "
            f"max_loss_Rs={round((self.wing_pts - net_credit) * qty, 0):,.0f}"
        )

    # ------------------------------------------------------------------
    # Exit monitoring
    # ------------------------------------------------------------------

    def _monitor_exits(self, now: datetime) -> None:
        pos  = self._position
        spot = self._get_spot()

        if spot <= 0:
            logger.warning("Spot unavailable — skipping exit check this cycle")
            return

        # Priority 1: hard stop — spot at or beyond a short strike
        if spot >= pos.short_ce or spot <= pos.short_pe:
            logger.warning(
                f"HARD_STOP  spot={spot:.0f}  "
                f"short_ce={pos.short_ce}  short_pe={pos.short_pe}"
            )
            self._close(now, spot, "HARD_STOP")
            return

        # Priority 2: EOD
        if now.time() >= self.eod_exit_time:
            logger.info(f"EOD exit at {now.strftime('%H:%M')}")
            self._close(now, spot, "EOD")
            return

        # Priority 3 & 4: P&L checks require live option prices
        cost = self._cost_to_close()
        if cost < 0:
            logger.warning("Option LTPs unavailable — skipping P&L check this cycle")
            return

        mtm_pts = round(pos.net_credit - cost, 2)
        mtm_inr = round(mtm_pts * pos.total_units, 2)

        logger.info(
            f"  spot={spot:.0f}  cost_to_close={cost:.2f}  "
            f"credit={pos.net_credit:.2f}  "
            f"mtm={mtm_pts:+.2f} pts  Rs{mtm_inr:+,.0f}  "
            f"target<={pos.profit_target_pts:.2f}  sl>={pos.sl_pts:.2f}"
        )

        self._write_mtm(now, spot, cost, mtm_pts, mtm_inr, "open")

        if cost <= pos.profit_target_pts:
            logger.info(f"PROFIT_TARGET hit: cost={cost:.2f} <= target={pos.profit_target_pts:.2f}")
            self._close(now, spot, "PROFIT_TARGET")
        elif cost >= pos.sl_pts:
            logger.warning(f"STOP_LOSS hit: cost={cost:.2f} >= sl={pos.sl_pts:.2f}")
            self._close(now, spot, "SL")

    def _close(self, now: datetime, spot: float, reason: str) -> None:
        pos = self._position
        qty = pos.total_units

        # Exit with market orders — speed over price on all exits
        self._place_orders([
            (pos.short_ce_sym, qty, "BUY",  0.0),
            (pos.long_ce_sym,  qty, "SELL", 0.0),
            (pos.short_pe_sym, qty, "BUY",  0.0),
            (pos.long_pe_sym,  qty, "SELL", 0.0),
        ], tag="EXIT", market=True)

        # Fetch post-close cost for accurate P&L (may be stale by a few seconds)
        cost = self._cost_to_close()
        if cost < 0:
            cost = 0.0  # unknown; will show as credit-is-profit

        pnl_pts = round(pos.net_credit - cost, 2)
        pnl_inr = round(pnl_pts * qty, 2)

        pos.status = "closed"
        self._save_state()
        self._write_mtm(now, spot, cost, pnl_pts, pnl_inr, reason)

        if self.dry_run:
            self._log_dry_run_snapshot(pos, now, spot, cost, pnl_pts, pnl_inr, reason)

        self._log_trade(TradeRecord(
            entry_date    = pos.entry_date,
            entry_time    = pos.entry_time,
            exit_time     = now.isoformat(),
            exit_reason   = reason,
            entry_spot    = pos.entry_spot,
            exit_spot     = spot,
            atm           = pos.atm,
            short_ce      = pos.short_ce,
            long_ce       = pos.long_ce,
            short_pe      = pos.short_pe,
            long_pe       = pos.long_pe,
            net_credit    = pos.net_credit,
            cost_to_close = cost,
            pnl_points    = pnl_pts,
            pnl_rupees    = pnl_inr,
            lots          = pos.lots,
        ))

        logger.info(
            f"CLOSED [{reason}]  "
            f"credit={pos.net_credit:.1f}  cost={cost:.1f}  "
            f"pnl={pnl_pts:+.1f} pts  ₹{pnl_inr:+,.0f}"
        )

    # ------------------------------------------------------------------
    # Market data helpers
    # ------------------------------------------------------------------

    def _get_spot(self) -> float:
        try:
            return float(self.broker.get_ltp(self.spot_symbol, exchange="NSE"))
        except Exception as exc:
            logger.error(f"get_spot failed: {exc}")
            return 0.0

    def _fetch_quotes(self, symbols: List[str]) -> Dict[str, float]:
        result: Dict[str, float] = {}
        for sym in symbols:
            try:
                result[sym] = float(self.broker.get_ltp(sym, exchange=self.exchange))
            except Exception as exc:
                logger.error(f"get_ltp({sym}) failed: {exc}")
                result[sym] = 0.0
        return result

    def _cost_to_close(self) -> float:
        """
        Current net cost to buy back the condor (points per unit).
        = current_short_ce_ltp - current_long_ce_ltp
        + current_short_pe_ltp - current_long_pe_ltp
        Returns -1.0 if quotes are unavailable.
        """
        pos = self._position
        q = self._fetch_quotes([
            pos.short_ce_sym, pos.long_ce_sym,
            pos.short_pe_sym, pos.long_pe_sym,
        ])
        if q.get(pos.short_ce_sym, 0) <= 0 or q.get(pos.short_pe_sym, 0) <= 0:
            return -1.0
        return max(
            (q[pos.short_ce_sym] - q.get(pos.long_ce_sym, 0.0))
            + (q[pos.short_pe_sym] - q.get(pos.long_pe_sym, 0.0)),
            0.0,
        )

    # ------------------------------------------------------------------
    # Order placement
    # ------------------------------------------------------------------

    def _place_orders(
        self,
        orders: List[Tuple[str, int, str, float]],  # (symbol, qty, side, limit_px)
        tag:    str,
        market: bool = False,
    ) -> None:
        for sym, qty, side, px in orders:
            if self.dry_run:
                label = "MKT" if (market or px == 0) else f"LMT@{px:.1f}"
                logger.info(f"[DRY RUN] {tag:5}  {side:4}  {qty:5} × {sym}  {label}")
                continue

            try:
                if market or px == 0:
                    res = self.broker.place_market_order(
                        tradingsymbol    = sym,
                        quantity         = qty,
                        transaction_type = side,
                        exchange         = self.exchange,
                    )
                else:
                    res = self.broker.place_limit_order(
                        tradingsymbol    = sym,
                        quantity         = qty,
                        transaction_type = side,
                        price            = round(px, 1),
                        exchange         = self.exchange,
                    )

                oid = res.get("order_id") if isinstance(res, dict) else None
                if oid:
                    logger.info(f"{tag:5}  {side:4}  {qty:5} × {sym}  → order_id={oid}")
                    if not market and px > 0:
                        self._await_fill(oid, sym, qty, side)
                else:
                    logger.error(f"{tag} order returned no order_id: {res}")

            except Exception as exc:
                logger.error(f"{tag} order exception for {sym}: {exc}")

    def _await_fill(self, oid: str, sym: str, qty: int, side: str) -> None:
        """Wait for a limit order to fill; convert to market after timeout."""
        deadline = time.monotonic() + self.fill_timeout_sec
        while time.monotonic() < deadline:
            time.sleep(2)
            try:
                s = self.broker.get_order_status(oid)
                if s and s.get("status") in ("COMPLETE", "FILLED", 2, "2"):
                    logger.info(f"Order {oid} filled.")
                    return
            except Exception:
                pass

        logger.warning(
            f"Limit order {oid} unfilled after {self.fill_timeout_sec}s — converting to market"
        )
        try:
            self.broker.cancel_order(oid)
        except Exception:
            pass
        try:
            self.broker.place_market_order(
                tradingsymbol    = sym,
                quantity         = qty,
                transaction_type = side,
                exchange         = self.exchange,
            )
        except Exception as exc:
            logger.error(f"Market fallback failed for {sym}: {exc}")

    # ------------------------------------------------------------------
    # Option symbol builder
    # ------------------------------------------------------------------

    def _opt_sym(self, strike: int, opt_type: str) -> str:
        """Build a fully-qualified broker option symbol."""
        return f"{self.exchange}:{self.symbol}{self.expiry}{strike}{opt_type}"

    # ------------------------------------------------------------------
    # State persistence
    # ------------------------------------------------------------------

    @property
    def _state_file(self) -> Path:
        return self.state_dir / "iron_condor_state.json"

    @property
    def _mtm_file(self) -> Path:
        return self.state_dir / "iron_condor_mtm.json"

    def _write_mtm(
        self,
        now: datetime,
        spot: float,
        cost: float,
        mtm_pts: float,
        mtm_inr: float,
        status: str,
    ) -> None:
        pos = self._position
        if pos is None:
            return
        data = {
            "timestamp":        now.isoformat(),
            "status":           status,
            "spot":             spot,
            "entry_spot":       pos.entry_spot,
            "entry_time":       pos.entry_time,
            "atm":              pos.atm,
            "short_ce":         pos.short_ce,
            "short_pe":         pos.short_pe,
            "long_ce":          pos.long_ce,
            "long_pe":          pos.long_pe,
            "net_credit":       pos.net_credit,
            "cost_to_close":    round(cost, 2),
            "mtm_pts":          mtm_pts,
            "mtm_inr":          mtm_inr,
            "profit_target_pts": pos.profit_target_pts,
            "sl_pts":           pos.sl_pts,
            "lots":             pos.lots,
            "lot_size":         pos.lot_size,
        }
        try:
            self._mtm_file.write_text(json.dumps(data, indent=2))
        except Exception as exc:
            logger.error(f"_write_mtm failed: {exc}")

    def _save_state(self) -> None:
        try:
            data = asdict(self._position) if self._position else None
            self._state_file.write_text(json.dumps(data, indent=2))
        except Exception as exc:
            logger.error(f"_save_state failed: {exc}")

    def _load_state(self) -> None:
        if not self._state_file.exists():
            return
        try:
            raw = json.loads(self._state_file.read_text())
            if raw:
                pos = CondorPosition(**raw)
                if pos.entry_date == date.today().isoformat() and pos.status == "open":
                    self._position = pos
                    logger.info(
                        f"Restored open position from {self._state_file}: "
                        f"{pos.entry_time}  credit={pos.net_credit:.1f}"
                    )
        except Exception as exc:
            logger.error(f"_load_state failed: {exc}")

    # ------------------------------------------------------------------
    # Trade log (CSV)
    # ------------------------------------------------------------------

    _LOG_FIELDS = [
        "entry_date", "entry_time", "exit_time", "exit_reason",
        "entry_spot", "exit_spot", "atm",
        "short_ce", "long_ce", "short_pe", "long_pe",
        "net_credit", "cost_to_close", "pnl_points", "pnl_rupees", "lots",
    ]

    @property
    def _log_file(self) -> Path:
        return self.log_dir / "iron_condor_trades.csv"

    def _log_trade(self, record: TradeRecord) -> None:
        new_file = not self._log_file.exists()
        try:
            with open(self._log_file, "a", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=self._LOG_FIELDS)
                if new_file:
                    writer.writeheader()
                writer.writerow(asdict(record))
            logger.info(f"Trade logged -> {self._log_file}")
        except Exception as exc:
            logger.error(f"_log_trade failed: {exc}")

    # ------------------------------------------------------------------
    # Dry run journal (persistent across sessions)
    # ------------------------------------------------------------------

    _DRY_JOURNAL_FIELDS = [
        "record_type",       # ENTRY | SNAPSHOT
        "timestamp",
        "entry_date",
        "entry_time",
        "expiry",
        "symbol",
        "spot",
        "atm",
        "short_ce", "long_ce", "short_pe", "long_pe",
        "short_ce_px", "long_ce_px", "short_pe_px", "long_pe_px",
        "net_credit",
        "cost_to_close",
        "pnl_pts",
        "pnl_inr",
        "lots",
        "lot_size",
        "exit_reason",
    ]

    @property
    def _dry_journal_file(self) -> Path:
        return self.log_dir / "dry_run_journal.csv"

    def _write_dry_journal_row(self, row: dict) -> None:
        new_file = not self._dry_journal_file.exists()
        try:
            with open(self._dry_journal_file, "a", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=self._DRY_JOURNAL_FIELDS, extrasaction="ignore")
                if new_file:
                    writer.writeheader()
                writer.writerow(row)
        except Exception as exc:
            logger.error(f"dry journal write failed: {exc}")

    def _log_dry_run_entry(self, pos: "CondorPosition", px: Dict[str, float]) -> None:
        self._write_dry_journal_row({
            "record_type":  "ENTRY",
            "timestamp":    pos.entry_time,
            "entry_date":   pos.entry_date,
            "entry_time":   pos.entry_time,
            "expiry":       self.expiry,
            "symbol":       self.symbol,
            "spot":         pos.entry_spot,
            "atm":          pos.atm,
            "short_ce":     pos.short_ce,
            "long_ce":      pos.long_ce,
            "short_pe":     pos.short_pe,
            "long_pe":      pos.long_pe,
            "short_ce_px":  px.get("short_ce", pos.short_ce_entry_px),
            "long_ce_px":   px.get("long_ce",  pos.long_ce_entry_px),
            "short_pe_px":  px.get("short_pe", pos.short_pe_entry_px),
            "long_pe_px":   px.get("long_pe",  pos.long_pe_entry_px),
            "net_credit":   pos.net_credit,
            "cost_to_close": "",
            "pnl_pts":      "",
            "pnl_inr":      "",
            "lots":         pos.lots,
            "lot_size":     pos.lot_size,
            "exit_reason":  "",
        })
        logger.info(f"Dry run entry journaled -> {self._dry_journal_file}")

    def _log_dry_run_snapshot(
        self,
        pos: "CondorPosition",
        now: datetime,
        spot: float,
        cost: float,
        pnl_pts: float,
        pnl_inr: float,
        reason: str,
    ) -> None:
        q = self._fetch_quotes([
            pos.short_ce_sym, pos.long_ce_sym,
            pos.short_pe_sym, pos.long_pe_sym,
        ])
        self._write_dry_journal_row({
            "record_type":   "SNAPSHOT",
            "timestamp":     now.isoformat(),
            "entry_date":    pos.entry_date,
            "entry_time":    pos.entry_time,
            "expiry":        self.expiry,
            "symbol":        self.symbol,
            "spot":          spot,
            "atm":           pos.atm,
            "short_ce":      pos.short_ce,
            "long_ce":       pos.long_ce,
            "short_pe":      pos.short_pe,
            "long_pe":       pos.long_pe,
            "short_ce_px":   q.get(pos.short_ce_sym, 0.0),
            "long_ce_px":    q.get(pos.long_ce_sym,  0.0),
            "short_pe_px":   q.get(pos.short_pe_sym, 0.0),
            "long_pe_px":    q.get(pos.long_pe_sym,  0.0),
            "net_credit":    pos.net_credit,
            "cost_to_close": cost,
            "pnl_pts":       pnl_pts,
            "pnl_inr":       pnl_inr,
            "lots":          pos.lots,
            "lot_size":      pos.lot_size,
            "exit_reason":   reason,
        })
        logger.info(f"Dry run snapshot journaled -> {self._dry_journal_file}  reason={reason}  pnl={pnl_pts:+.1f} pts")
