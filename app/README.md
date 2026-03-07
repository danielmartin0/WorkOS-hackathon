# AdaL Overlay (macOS)

This app is a transparent game-overlay panel that runs a local `adal` terminal process and streams all terminal activity into the UI.

## What it does

- Sends your chat message to local `adal` via stdin
- Streams all stdout/stderr from `adal` back into the chat panel in real time
- Keeps the panel anchored to the selected game window

## Requirements

- macOS 14+
- Xcode 16+
- `adal` available in terminal PATH (or set `ADAL_COMMAND`)

## Run

```bash
cd /Users/hetpatel/Desktop/UI-HACK/app
./scripts/dev.sh
```

## Optional env

- `ADAL_COMMAND` (default: `adal`)
  - Example: `ADAL_COMMAND="adal --some-flag"`

## Notes

- The UI now uses local AdaL terminal bridging directly.
- Previous network sidecars are no longer part of the active chat flow.
