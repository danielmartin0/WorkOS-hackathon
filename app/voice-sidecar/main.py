from __future__ import annotations

import asyncio
import base64
import json
import os
import tempfile
import uuid
from dataclasses import dataclass, field
from typing import Any

import httpx
from dotenv import load_dotenv
from openai import AsyncOpenAI
from websockets.asyncio.server import ServerConnection, serve

load_dotenv()

VOICE_PORT = int(os.getenv("VOICE_PORT", "8787"))
AGENT_URL = os.getenv("AGENT_URL", "http://127.0.0.1:5051/agent/query")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

try:
    import pipecat  # type: ignore

    PIPECAT_AVAILABLE = True
except Exception:
    PIPECAT_AVAILABLE = False


@dataclass
class SessionState:
    session_id: str | None = None
    pcm_chunks: list[bytes] = field(default_factory=list)


def make_event(event_type: str, *, session_id: str | None = None, text: str | None = None, audio: bytes | None = None, error: str | None = None) -> str:
    payload: dict[str, Any] = {"type": event_type}
    if session_id:
        payload["sessionId"] = session_id
    if text is not None:
        payload["text"] = text
    if audio is not None:
        payload["audioBase64"] = base64.b64encode(audio).decode("utf-8")
    if error is not None:
        payload["error"] = error
    return json.dumps(payload)


async def query_agent(transcript: str, session_id: str | None) -> tuple[str, str]:
    async with httpx.AsyncClient(timeout=90.0) as client:
        response = await client.post(
            AGENT_URL,
            json={
                "prompt": transcript,
                "sessionId": session_id,
            },
        )
        response.raise_for_status()
        data = response.json()
    return str(data.get("text", "")), str(data.get("sessionId", session_id or uuid.uuid4().hex))


async def transcribe_audio(client: AsyncOpenAI | None, pcm_chunks: list[bytes]) -> str:
    if not pcm_chunks:
        return ""

    blob = b"".join(pcm_chunks)
    if client is None:
        return "(voice input captured; set OPENAI_API_KEY to enable transcription)"

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
        tmp.write(blob)
        tmp.flush()
        with open(tmp.name, "rb") as audio_file:
            result = await client.audio.transcriptions.create(
                model="gpt-4o-mini-transcribe",
                file=audio_file,
            )

    return getattr(result, "text", "") or ""


async def synthesize_audio(client: AsyncOpenAI | None, text: str) -> bytes:
    if not text:
        return b""
    if client is None:
        return b""

    result = await client.audio.speech.create(
        model="gpt-4o-mini-tts",
        voice="alloy",
        input=text,
        response_format="mp3",
    )
    return await result.aread()


async def handle_socket(websocket: ServerConnection) -> None:
    state = SessionState()
    openai_client = AsyncOpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None

    async for message in websocket:
        if not isinstance(message, str):
            await websocket.send(make_event("error", error="binary frames are not supported"))
            continue

        try:
            event = json.loads(message)
            event_type = event.get("type")
        except json.JSONDecodeError:
            await websocket.send(make_event("error", error="invalid json"))
            continue

        if event_type == "session.start":
            state.session_id = event.get("sessionId") or uuid.uuid4().hex
            await websocket.send(make_event("transcript.partial", session_id=state.session_id, text="listening"))
            continue

        if event_type == "audio.chunk":
            chunk = event.get("audioBase64")
            if isinstance(chunk, str):
                try:
                    state.pcm_chunks.append(base64.b64decode(chunk))
                except Exception:
                    await websocket.send(make_event("error", session_id=state.session_id, error="invalid audio chunk"))
            continue

        if event_type == "session.stop":
            await websocket.send(make_event("transcript.partial", session_id=state.session_id, text="transcribing"))
            transcript = await transcribe_audio(openai_client, state.pcm_chunks)
            state.pcm_chunks.clear()

            await websocket.send(make_event("transcript.final", session_id=state.session_id, text=transcript))

            if not transcript:
                continue

            try:
                agent_text, next_session = await query_agent(transcript, state.session_id)
                state.session_id = next_session
                await websocket.send(make_event("agent.text", session_id=state.session_id, text=agent_text))

                audio = await synthesize_audio(openai_client, agent_text)
                if audio:
                    await websocket.send(make_event("audio.chunk", session_id=state.session_id, audio=audio))
            except Exception as exc:
                await websocket.send(make_event("error", session_id=state.session_id, error=str(exc)))


async def main() -> None:
    if PIPECAT_AVAILABLE:
        print("Pipecat dependency detected. Running WS sidecar with Pipecat-ready pipeline contract.")
    else:
        print("Pipecat not installed; running fallback WS pipeline.")

    async with serve(handle_socket, "127.0.0.1", VOICE_PORT, max_size=6_000_000):
        print(f"Voice sidecar listening on ws://127.0.0.1:{VOICE_PORT}/ws/voice")
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
