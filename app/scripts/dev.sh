#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

if [ ! -d "agent-sidecar/node_modules" ]; then
  npm --prefix agent-sidecar install
fi

swift run OverlayApp
