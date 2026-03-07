#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
FACTORIO_BIN="$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio"
SAVE_DIR="./saves"
SAVE_NAME="my-map"
SAVE_PATH="${SAVE_DIR}/${SAVE_NAME}.zip"
SERVER_SETTINGS="./server-settings.json"
RCON_PORT=27015
RCON_PASSWORD="mysecretpassword"
GAME_PORT=34197

# --- Verify binary exists ---
if [[ ! -x "$FACTORIO_BIN" ]]; then
    # Try standalone install as fallback
    STANDALONE_BIN="/Applications/Factorio.app/Contents/MacOS/factorio"
    if [[ -x "$STANDALONE_BIN" ]]; then
        FACTORIO_BIN="$STANDALONE_BIN"
        echo "Using standalone install: $FACTORIO_BIN"
    else
        echo "Error: Factorio binary not found at $FACTORIO_BIN"
        echo "If installed elsewhere, edit FACTORIO_BIN in this script."
        exit 1
    fi
fi

# --- Create saves directory ---
mkdir -p "$SAVE_DIR"

# --- Generate default server-settings.json if missing ---
if [[ ! -f "$SERVER_SETTINGS" ]]; then
    cat > "$SERVER_SETTINGS" <<'EOF'
{
    "name": "My Factorio Server",
    "description": "Local server",
    "tags": [],
    "max_players": 0,
    "visibility": { "public": false, "lan": true },
    "require_user_verification": false,
    "max_heartbeats_per_second": 60,
    "allow_commands": "admins-only",
    "autosave_interval": 5,
    "autosave_slots": 3,
    "afk_autokick_interval": 0,
    "auto_pause": true,
    "only_admins_can_pause_the_game": true,
    "max_upload_in_kilobytes_per_second": 0,
    "max_upload_slots": 5
}
EOF
    echo "Created default $SERVER_SETTINGS"
fi

# --- Create map if save doesn't exist ---
if [[ ! -f "$SAVE_PATH" ]]; then
    echo "Creating new map at $SAVE_PATH ..."
    "$FACTORIO_BIN" --create "$SAVE_PATH"
fi

# --- Start server ---
echo ""
echo "Starting Factorio server..."
echo "  Game port: $GAME_PORT/udp"
echo "  RCON port: $RCON_PORT/tcp"
echo "  RCON pass: $RCON_PASSWORD"
echo ""
echo "Connect from Factorio: Multiplayer → Connect to address → localhost"
echo "Press Ctrl+C to stop."
echo ""

exec "$FACTORIO_BIN" \
    --start-server "$SAVE_PATH" \
    --server-settings "$SERVER_SETTINGS" \
    --port "$GAME_PORT" \
    --rcon-port "$RCON_PORT" \
    --rcon-password "$RCON_PASSWORD"
