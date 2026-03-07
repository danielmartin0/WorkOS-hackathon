#!/usr/bin/env bash
set -euo pipefail

TTY_PATH="$(tty || true)"
if [[ "${TTY_PATH}" == "not a tty" ]]; then
  echo "[overlay] bridge-adal.sh must run inside an interactive terminal." >&2
  exit 1
fi

TTY_NAME="${TTY_PATH#/dev/}"
LOG_ROOT="${HOME}/.adal-overlay"
SAFE_TTY="$(echo "${TTY_NAME}" | tr -c '[:alnum:]._-' '_')"
LOG_FILE="${LOG_ROOT}/${SAFE_TTY}.log"

mkdir -p "${LOG_ROOT}"
touch "${LOG_FILE}"

# Mirror all Adal output so the overlay can stream it in real time.
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "[overlay] bridge active on ${TTY_NAME}"
echo "[overlay] streaming to ${LOG_FILE}"

exec adal "$@"
