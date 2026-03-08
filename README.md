# GAMEJAM — Game Prototyping Overlay

The GAMEJAM hackathon project is an app that overlays on top of existing game applications and sends them commands via RCON, along with generating assets that are incorporated into the game.

## Components

- **`mod/`** — Factorio 2.0 mod (Lua) that receives RCON commands and applies changes in-game
- **`overlay-electron/`** — Electron-based transparent overlay that renders the chat UI on top of the game
- **`factorio-server/`**

## Screenshot

![GAMEJAM overlay on Factorio](screenshot.png)
