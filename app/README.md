# macOS Transparent Overlay App

This folder contains the v1 implementation for the macOS overlay app and local sidecars.

## Structure

- `Sources/OverlayApp` - executable entrypoint
- `Sources/OverlayCore` - overlay UI + services
- `agent-sidecar` - local Claude Agent SDK HTTP service (`POST /agent/query`)

## Requirements

- macOS 14+
- Xcode 16+
- Node 20+
- Python 3.11+
- `uv`

## Environment

Copy `.env.example` to `.env` and set:

- `ANTHROPIC_API_KEY`

## Run (dev)

```bash
cd /Users/hetpatel/Desktop/UI-HACK/app
./scripts/dev.sh
```

## API Contracts

### Agent sidecar

`POST /agent/query`

```json
{
  "prompt": "string",
  "sessionId": "optional string",
  "screenshotPath": "optional absolute path inside repo root"
}
```

Response:

```json
{
  "text": "string",
  "sessionId": "string"
}
```

## Notes

- Agent sidecar hard-locks tool permissions to `Read` and `Write`.
- `AGENT_WORKDIR` is enforced for screenshot path safety and defaults to repo root (`/Users/.../UI-HACK`) so the agent can read/write files in `/mod`.
- Overlay window is borderless/transparent and click-through outside controls.
- Voice is intentionally disabled in this build while text + screenshot flow is stabilized.
