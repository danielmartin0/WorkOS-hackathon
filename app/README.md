# AdaL Overlay (macOS)

This app is a transparent game-overlay chat panel that attaches to already-running local `adal` terminals.

## What it does

- Discovers running `adal` terminal sessions (PID + TTY)
- Lets you switch/attach between those sessions in UI
- Sends your message to the selected terminal by writing to its TTY
- Streams live terminal activity from the selected session into the chat panel

## Requirements

- macOS 14+
- Xcode 16+
- `adal` processes already running in terminal tabs/windows

## Run

```bash
cd /Users/hetpatel/Desktop/UI-HACK/app
./scripts/dev.sh
```

## Usage

1. Start one or more `adal` sessions in terminal windows.
2. Open overlay app and click `Refresh Sessions`.
3. Pick a session (auto-attaches) or click `Attach`.
4. Send messages; all terminal activity appears in the chat feed.

## Notes

- This mode does **not** launch `adal`; it only attaches to existing sessions.
- Session switching is handled from the session picker in UI.
