# AutoTrader — User Guide

A friendly guide to using the AutoTrader app. No trading or technical background
needed. You can also find a short version inside the app at **More → Help**.

---

## 1. What this app does

AutoTrader runs small programs called **bots** that buy and sell options
automatically, using a strategy you choose and your broker account. You stay in
control: you create bots, start and stop them, and watch how they're doing.

**Everything starts in Practice mode — no real money — so you can explore safely.**

---

## 2. Words you'll see

| Word | What it means |
|---|---|
| **Bot** | A small program that trades automatically for you. |
| **Broker** | Your trading account (e.g. Zerodha, Fyers) that actually places trades. |
| **Trading style** | The rules a bot follows. See the three styles below. |
| **Practice mode** | Simulated trading. Nothing real is bought or sold. |
| **Live mode** | Real trades with real money. The app always asks you to confirm this. |
| **Access code** | An admin code that unlocks creating and controlling bots. Your provider gives it to you. |
| **Open P&L** | Your profit or loss right now on an open position. |
| **Reconnect** | Logging in to your broker again (broker logins expire daily). |

### Trading styles
- **Range Income** *(recommended for beginners, lower risk)* — earns when the
  market stays calm and range-bound.
- **Volatility Spike** *(higher risk)* — trades quick moves when the market is jumpy.
- **Trend Follower** *(higher risk)* — rides sustained up or down moves.

---

## 3. First-time setup (about 5 minutes)

When you first open the app, a short guide appears:

1. **Welcome** — a quick intro.
2. **Enter your access code** — paste the **admin access code** your provider gave
   you. (You can skip this and explore first, but you'll need it before creating a
   bot.) The server address is pre-filled; most people leave it as-is.
3. **Connect a broker** — explained here; you can do it now or later.
4. **You're set** — finish.

> Don't have an access code? You can still look around. When you try to create a
> bot, the app will tell you you need one and point you to **Settings**.

---

## 4. The four tabs

### 🏠 Home
Your dashboard. At a glance it shows:
- Whether a bot is **running**, its style, and whether it's **Practice** or **Live**.
- **Open P&L** (from your main account).
- Your **broker** connection (tap it to connect or manage).
- **Alerts** when something needs you (e.g. "bot isn't responding", "no broker
  connected") — each has a button to fix it.
- Quick actions: **New bot**, **Activity**, **Checkup**.

### 🤖 Bots
Your list of bots. For each bot you'll see its name, style, broker, and status.
- Tap the **▶ / ◼** button on a row to start or stop that bot.
- Tap the row to open the bot's **details**.
- Tap **+** (top right) to create a new bot.
- Swipe a row left for quick **Restart / Delete**; long-press for more options.

### 📈 Activity
- **Open** — your live position and its profit/loss right now.
- **History** — past trades, newest first.
- **Stats** — totals: profit/loss, number of trades, wins, losses, win rate.

### ⋯ More
- **Brokers** — connect or reconnect Fyers / Zerodha / TradeSmart.
- **System check** — confirms the server, broker, and data feed are OK.
- **Activity logs** — detailed technical logs (Engine / API / Scalp).
- **Settings** — server address, your access code, appearance.
- **Help** — a short version of this guide.
- **Advanced** — original power-user controls. Most people can ignore this.

---

## 5. Connect a broker

A broker is the account that places real trades. **You don't need one for Practice
mode**, but you do for Live trading.

1. Go to **More → Brokers** (or tap the **Broker** card on Home).
2. Tap **Connect** next to your broker.
3. A secure web login opens — sign in with your broker.
4. When it returns, the broker shows **Connected**.

Broker logins **expire at the end of each day**, so you'll reconnect from time to
time. The app reminds you on Home when a broker needs reconnecting.

---

## 6. Create your first bot

From **Bots**, tap **+** (or **Create your first bot** on Home). A 4-step guide
appears:

1. **Pick a trading style** — tap one (Range Income is a gentle start).
2. **Choose a broker** — each shows whether it's connected ("Not connected —
   Practice only" is fine for now).
3. **Name your bot** — anything memorable, e.g. "My Range Bot".
4. **Review & create** — leave **Practice mode** on for now. Optionally turn on
   **Start right away**, then tap **Create bot**.

Your bot appears in the **Bots** list and on **Home**.

---

## 7. Start, stop, and manage a bot

- **Start / Stop** — use the **▶ / ◼** button on the bot's row, or open the bot and
  use the big **Start / Stop / Restart** buttons.
- **Restart** — use this if a bot says it **isn't responding**, or after changing a
  setting.
- **Practice ↔ Live** — open the bot, toggle **Practice mode**. Turning it **off**
  (Live) is a real-money change, so the app warns you. **Restart the bot** for the
  change to take effect.
- **Reconnect broker** — open the bot → **Reconnect {broker}**. Log in, and the bot's
  broker login updates automatically. Restart the bot afterwards.
- **Delete** — swipe the row or use the bot's screen. This stops and removes the
  bot; your saved broker login is kept on the server.

> Starting a **Live** bot whose broker isn't connected will warn you first — live
> trades can fail without a connected broker.

---

## 8. Reading your results

- **Home → Open P&L** shows your current profit/loss on an open position (from your
  main account).
- **Activity → Open** shows the live position in detail.
- **Activity → History / Stats** show completed trades and overall performance.
  Practice trades are included.

Green means profit, red means loss. A win-rate is the share of trades that ended
positive.

---

## 9. If something looks wrong

The app explains problems in plain language and offers a fix. Common cases:

| You see | What it means | What to do |
|---|---|---|
| "Can't reach the server" | No connection. | Check your internet, then **Try Again**. |
| "Server is restarting" | The server is briefly unavailable. | Wait a moment; it retries on its own. |
| "Admin code needed" | Your access code is missing or wrong. | Add/fix it in **Settings**. |
| Bot "isn't responding" | A bot stopped checking in. | Open it and tap **Restart**. |
| "No broker connected" | No broker login. | **More → Brokers → Connect**. |
| "Finish the broker login" | The broker login didn't complete. | Reconnect and complete the web login. |
| System check shows a warning/error | Something a bot relies on is degraded. | Open **More → System check** for details. |

You're **offline**? The app keeps showing the last known info and tells you at the
top of Home.

---

## 10. Staying safe

- Bots **default to Practice mode**. Switching to **Live** always asks you to confirm.
- A **Live** bot is clearly badged on Home and in its row.
- Your **access code** is stored securely on your device only and is never shown in
  logs.
- Reads (viewing status) don't need the code; only changes (create/start/stop/
  delete) do.

---

## 11. Settings quick reference

**More → Settings**:
- **Server URL** — where your bots run (usually leave as-is).
- **Access code** — paste your admin code; **Change access code on server** lets you
  rotate it.
- **Test Connection** — checks the app can reach the server.
- **Appearance / Version** — app info.

---

*Short in-app version: **More → Help**. Questions about your access code or broker
setup go to whoever runs your server.*
