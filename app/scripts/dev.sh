#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

if [ ! -d "agent-sidecar/node_modules" ]; then
  npm --prefix agent-sidecar install
fi

(
  cd "$ROOT_DIR/voice-sidecar"
  uv sync
)

npm --prefix agent-sidecar run dev &
AGENT_PID=$!

uv run --directory "$ROOT_DIR/voice-sidecar" python main.py &
VOICE_PID=$!

cleanup() {
  kill "$AGENT_PID" "$VOICE_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

swift run OverlayApp
