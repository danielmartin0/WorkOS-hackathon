#!/usr/bin/env bash
set -euo pipefail

SESSION_NAME="${ADAL_TMUX_SESSION:-adal}"
if [[ "${1:-}" == "--session" ]]; then
  SESSION_NAME="${2:-adal}"
  shift 2
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is required. Install tmux and retry." >&2
  exit 1
fi

ADAL_CMD=(adal "$@")
tmux new-session -Ad -s "${SESSION_NAME}" "${ADAL_CMD[*]}"
exec tmux attach -t "${SESSION_NAME}"
