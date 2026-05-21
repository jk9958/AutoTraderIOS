# AutoTrader iOS

Native iOS client for the [kite-auto-trader](https://github.com/jk9958/Auto_Option) backend.

Controls NIFTY/SENSEX options trading engines from your iPhone — start/stop engines, refresh broker tokens, stream live logs, and review trades.

## Requirements

See [REQUIREMENTS.md](REQUIREMENTS.md) for the full product specification.

## Stack

- Swift 5.9+ / SwiftUI
- iOS 16.0+
- No third-party dependencies
- Backend: FastAPI server at `http://100.124.30.59:8000` (Tailscale)

## Setup

1. Clone this repo.
2. Open `AutoTraderIOS.xcodeproj` in Xcode 15+.
3. In **Settings** inside the app, set the server base URL to your Tailscale IP.
4. Ensure Tailscale is running on your iPhone and Windows machine.

## Related

- Backend server: [`src/api_server.py`](https://github.com/jk9958/Auto_Option/blob/develop/src/api_server.py)
- Server setup guide: [`SERVER_SETUP.md`](https://github.com/jk9958/Auto_Option/blob/develop/SERVER_SETUP.md)
