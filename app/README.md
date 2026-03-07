# macOS Transparent Overlay App

This folder contains the v1 implementation for the macOS overlay app and local sidecars.

## Structure

- `Sources/OverlayApp` - executable entrypoint
- `Sources/OverlayCore` - overlay UI + services
- `agent-sidecar` - local Claude Agent SDK HTTP service (`POST /agent/query`)
- `voice-sidecar` - local voice WebSocket service (`ws://127.0.0.1:8787/ws/voice`)

## Requirements

- macOS 14+
- Xcode 16+
- Node 20+
- Python 3.11+
- `uv`

## Environment

Copy `.env.example` to `.env` and set:

- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`

## Run (dev)

```bash
cd /Users/hetpatel/Desktop/UI-HACK/app
./scripts/dev.sh
```

To install Pipecat extras explicitly:

```bash
cd /Users/hetpatel/Desktop/UI-HACK/app/voice-sidecar
uv sync --extra pipecat
```

## API Contracts

### Agent sidecar

`POST /agent/query`

```json
{
  "prompt": "string",
  "sessionId": "optional string",
  "screenshotPath": "optional absolute path inside /app"
}
```

Response:

```json
{
  "text": "string",
  "sessionId": "string"
}
```

### Voice sidecar WS protocol

Client -> server:

- `session.start`
- `audio.chunk`
- `session.stop`

Server -> client:

- `transcript.partial`
- `transcript.final`
- `agent.text`
- `audio.chunk`
- `error`

## Notes

- Agent sidecar hard-locks tool permissions to `Read` and `Write`.
- `AGENT_WORKDIR` is enforced for screenshot path safety.
- Overlay window is borderless/transparent and click-through outside controls.
