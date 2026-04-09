# Server-Side Changes for iOS App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the Alfred Python backend to support the iOS app — multi-format audio, iOS channel, trusted network auth, APNs push notifications, and device registration.

**Architecture:** Six targeted changes in the existing `alfred/` monorepo. No new processes or architectural shifts — just extending existing patterns (new channel adapter, new REST endpoints, wider audio format support).

**Tech Stack:** Python 3.13, FastAPI, Redis, Pydantic v2, httpx (h2), faster-whisper, pytest

**Spec:** `alfred-ios/docs/specs/2026-04-03-ios-app-design.md` — Server-Side Changes section

**Working directory:** `/Users/anirudhlath/code/private/alfred/alfred/`

---

### Task 1: Add `"ios"` to Channel Literal and Accept `channel` from Client

**Files:**
- Modify: `bus/schemas/events.py:95,108`
- Modify: `core/channels/web_server.py:229-236`
- Test: `tests/bus/test_events_ios.py` (new)
- Test: `tests/core/channels/test_web_server_ios.py` (new)

- [ ] **Step 1: Write failing test for `UserRequest` with `"ios"` channel**

```python
# tests/bus/test_events_ios.py
from bus.schemas.events import UserRequest


def test_user_request_accepts_ios_channel() -> None:
    req = UserRequest(
        source="ios-app",
        channel="ios",
        session_id="test-session",
        identity_claim="sir",
        content_type="text",
        content="hello",
    )
    assert req.channel == "ios"


def test_alfred_response_accepts_ios_channel() -> None:
    from bus.schemas.events import AlfredResponse

    resp = AlfredResponse(
        source="conscious",
        channel="ios",
        session_id="test-session",
        text="hello",
    )
    assert resp.channel == "ios"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/bus/test_events.py -v`
Expected: FAIL — Pydantic validation error, `"ios"` not in Literal

- [ ] **Step 3: Add `"ios"` to the channel Literal**

In `bus/schemas/events.py`, change line 95:
```python
channel: Literal["web_pwa", "signal", "voice", "ios"]
```
And line 108:
```python
channel: Literal["web_pwa", "signal", "voice", "ios"]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/bus/test_events.py -v`
Expected: PASS

- [ ] **Step 5: Write failing test for WebSocket handler reading `channel` from client message**

```python
# tests/core/channels/test_web_server_ios.py
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient


@pytest.fixture
def mock_redis_pool():
    """Mock Redis pool to avoid lifespan needing a real Redis connection."""
    mock = AsyncMock()
    mock.close = AsyncMock()
    mock.xread = AsyncMock(return_value=[])
    mock.xadd = AsyncMock()
    return mock


@pytest.fixture
def app_with_mock_redis(mock_redis_pool):
    """Create app with mocked Redis — bypasses lifespan Redis connection."""
    with patch("core.channels.web_server.aioredis") as mock_aioredis:
        mock_aioredis.from_url.return_value = mock_redis_pool
        from core.channels.web_server import create_app

        app = create_app()
        # Pre-set Redis on app state so endpoints work
        app.state.redis = mock_redis_pool
        yield app


def test_websocket_uses_channel_from_client_message(app_with_mock_redis) -> None:
    """When client sends channel='ios', the UserRequest should use that channel."""
    captured_request: dict[str, str] = {}

    async def mock_publish_and_wait(redis, request, session_id, timeout=30.0):
        captured_request["channel"] = request.channel
        captured_request["source"] = request.source
        return "test response"

    with patch("core.channels.web_server._publish_and_wait", mock_publish_and_wait):
        client = TestClient(app_with_mock_redis)
        with client.websocket_connect("/ws") as ws:
            ws.send_json({
                "type": "text",
                "content": "hello",
                "identity": "sir",
                "channel": "ios",
            })
            # Read session message
            session_msg = ws.receive_json()
            assert session_msg["type"] == "session"
            # Read response
            response_msg = ws.receive_json()
            assert response_msg["type"] == "response"

    assert captured_request["channel"] == "ios"
    assert captured_request["source"] == "ios-app"


def test_websocket_defaults_to_web_pwa_without_channel(app_with_mock_redis) -> None:
    """When client omits channel field, default to web_pwa for backward compat."""
    captured_request: dict[str, str] = {}

    async def mock_publish_and_wait(redis, request, session_id, timeout=30.0):
        captured_request["channel"] = request.channel
        return "test response"

    with patch("core.channels.web_server._publish_and_wait", mock_publish_and_wait):
        client = TestClient(app_with_mock_redis)
        with client.websocket_connect("/ws") as ws:
            ws.send_json({
                "type": "text",
                "content": "hello",
                "identity": "sir",
            })
            ws.receive_json()  # session
            ws.receive_json()  # response

    assert captured_request["channel"] == "web_pwa"
```

- [ ] **Step 6: Run test to verify it fails**

Run: `python -m pytest tests/core/channels/test_web_server_ios.py -v`
Expected: FAIL — channel is still hardcoded to `"web_pwa"`

- [ ] **Step 7: Modify WebSocket handler to read `channel` from client message**

Add the channel-to-source mapping constant in `core/channels/web_server.py` after the existing imports (this is business logic, not a Redis constant, so it belongs here — not in `shared/streams.py`):

```python
# Channel-to-source mapping for UserRequest construction
_CHANNEL_SOURCE_MAP: dict[str, str] = {
    "ios": "ios-app",
    "web_pwa": "web-pwa",
    "voice": "web-pwa",
    "signal": "signal-bridge",
}
```

Replace lines 229-236:

```python
                # Read channel from client (iOS sends "ios", web PWA omits or sends "web_pwa")
                client_channel = data.get("channel", "web_pwa")
                request = UserRequest(
                    source=_CHANNEL_SOURCE_MAP.get(client_channel, "web-pwa"),
                    channel=client_channel,
                    session_id=session_id,
                    identity_claim=data.get("identity", "guest"),
                    content_type=content_type,
                    content=content,
                )
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `python -m pytest tests/core/channels/test_web_server_ios.py tests/bus/test_events_ios.py -v`
Expected: PASS

- [ ] **Step 9: Run full test suite to check for regressions**

Run: `python -m pytest -x -q`
Expected: All tests pass

- [ ] **Step 10: Lint and type-check**

Run: `ruff check bus/ core/channels/ --fix && ruff format bus/ core/channels/ && mypy --strict bus/ core/channels/`

- [ ] **Step 11: Commit**

```bash
git add bus/schemas/events.py core/channels/web_server.py tests/bus/test_events_ios.py tests/core/channels/test_web_server_ios.py
git commit -m "feat: add 'ios' channel and read channel from client WebSocket message"
```

---

### Task 2: Replace `require_localhost` with `require_trusted_network`

**Files:**
- Modify: `core/channels/web_server.py:109-113`
- Test: `tests/core/channels/test_trusted_network.py` (new)

- [ ] **Step 1: Write failing tests for trusted network guard**

```python
# tests/core/channels/test_trusted_network.py
import pytest
from unittest.mock import MagicMock

from fastapi import HTTPException


async def test_localhost_ipv4_allowed() -> None:
    from core.channels.web_server import require_trusted_network

    request = MagicMock()
    request.client.host = "127.0.0.1"
    await require_trusted_network(request)  # Should not raise


async def test_localhost_ipv6_allowed() -> None:
    from core.channels.web_server import require_trusted_network

    request = MagicMock()
    request.client.host = "::1"
    await require_trusted_network(request)  # Should not raise


async def test_tailscale_cgnat_allowed() -> None:
    from core.channels.web_server import require_trusted_network

    request = MagicMock()
    request.client.host = "100.100.50.25"
    await require_trusted_network(request)  # Should not raise


async def test_tailscale_cgnat_edge_low() -> None:
    from core.channels.web_server import require_trusted_network

    request = MagicMock()
    request.client.host = "100.64.0.1"
    await require_trusted_network(request)  # Should not raise


async def test_tailscale_cgnat_edge_high() -> None:
    from core.channels.web_server import require_trusted_network

    request = MagicMock()
    request.client.host = "100.127.255.254"
    await require_trusted_network(request)  # Should not raise


async def test_external_ip_rejected() -> None:
    from core.channels.web_server import require_trusted_network

    request = MagicMock()
    request.client.host = "203.0.113.50"
    with pytest.raises(HTTPException) as exc_info:
        await require_trusted_network(request)
    assert exc_info.value.status_code == 403


async def test_non_tailscale_100_range_rejected() -> None:
    """100.128.0.1 is outside the CGNAT /10 range."""
    from core.channels.web_server import require_trusted_network

    request = MagicMock()
    request.client.host = "100.128.0.1"
    with pytest.raises(HTTPException) as exc_info:
        await require_trusted_network(request)
    assert exc_info.value.status_code == 403


async def test_testclient_allowed() -> None:
    """TestClient uses 'testclient' as host — must still be allowed for tests."""
    from core.channels.web_server import require_trusted_network

    request = MagicMock()
    request.client.host = "testclient"
    await require_trusted_network(request)  # Should not raise
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/core/channels/test_trusted_network.py -v`
Expected: FAIL — `require_trusted_network` doesn't exist yet

- [ ] **Step 3: Implement `require_trusted_network`**

In `core/channels/web_server.py`, replace the `require_localhost` function (lines 109-113):

```python
import ipaddress


async def require_trusted_network(request: Request) -> None:
    """FastAPI dependency — restrict endpoint to localhost or Tailscale CGNAT range.

    Trusted networks:
    - 127.0.0.1, ::1 (localhost)
    - 100.64.0.0/10 (Tailscale CGNAT)
    - 'testclient' (Starlette test client)
    """
    client_host = request.client.host if request.client else ""
    if client_host in ("127.0.0.1", "::1", "testclient"):
        return
    try:
        addr = ipaddress.ip_address(client_host)
        tailscale_range = ipaddress.ip_network("100.64.0.0/10")
        if addr in tailscale_range:
            return
    except ValueError:
        pass
    raise HTTPException(status_code=403, detail="Access restricted to trusted networks")
```

- [ ] **Step 4: Update endpoint dependencies to use `require_trusted_network`**

In `core/channels/web_server.py`, change the two endpoint decorators (lines 284-286 and 320-322):

Replace `dependencies=[Depends(require_localhost)]` with `dependencies=[Depends(require_trusted_network)]` on both the `save_credentials` and `delete_credentials` endpoints.

- [ ] **Step 5: Run tests to verify they pass**

Run: `python -m pytest tests/core/channels/test_trusted_network.py -v`
Expected: PASS

- [ ] **Step 6: Run full test suite to check for regressions**

Run: `python -m pytest -x -q`
Expected: All tests pass. Any tests that previously called `require_localhost` directly will need updating if they exist.

- [ ] **Step 7: Lint and type-check**

Run: `ruff check core/channels/web_server.py --fix && ruff format core/channels/web_server.py && mypy --strict core/channels/`

- [ ] **Step 8: Commit**

```bash
git add core/channels/web_server.py tests/core/channels/test_trusted_network.py
git commit -m "feat: replace require_localhost with require_trusted_network (Tailscale CGNAT)"
```

---

### Task 3: Multi-Format Audio Intake

**Files:**
- Modify: `core/channels/web_server.py:70-74,191-196`
- Modify: `core/voice/stt.py:38-51`
- Test: `tests/core/channels/test_audio_format.py` (new)
- Test: `tests/core/voice/test_stt_format.py` (new)

- [ ] **Step 1: Write failing test for `_decode_audio` returning format**

```python
# tests/core/channels/test_audio_format.py
from core.channels.web_server import _decode_audio


def test_decode_audio_webm_returns_format() -> None:
    import base64

    raw = b"fake-webm-data"
    data_url = f"data:audio/webm;base64,{base64.b64encode(raw).decode()}"
    audio_bytes, fmt = _decode_audio(data_url)
    assert audio_bytes == raw
    assert fmt == "webm"


def test_decode_audio_aac_returns_format() -> None:
    import base64

    raw = b"fake-aac-data"
    data_url = f"data:audio/aac;base64,{base64.b64encode(raw).decode()}"
    audio_bytes, fmt = _decode_audio(data_url)
    assert audio_bytes == raw
    assert fmt == "aac"


def test_decode_audio_wav_returns_format() -> None:
    import base64

    raw = b"fake-wav-data"
    data_url = f"data:audio/wav;base64,{base64.b64encode(raw).decode()}"
    audio_bytes, fmt = _decode_audio(data_url)
    assert audio_bytes == raw
    assert fmt == "wav"


def test_decode_audio_m4a_returns_format() -> None:
    import base64

    raw = b"fake-m4a-data"
    data_url = f"data:audio/m4a;base64,{base64.b64encode(raw).decode()}"
    audio_bytes, fmt = _decode_audio(data_url)
    assert audio_bytes == raw
    assert fmt == "m4a"


def test_decode_audio_no_mime_defaults_to_wav() -> None:
    import base64

    raw = b"bare-data"
    bare_b64 = base64.b64encode(raw).decode()
    audio_bytes, fmt = _decode_audio(bare_b64)
    assert audio_bytes == raw
    assert fmt == "wav"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/core/channels/test_audio_format.py -v`
Expected: FAIL — `_decode_audio` returns `bytes`, not a tuple

- [ ] **Step 3: Update `_decode_audio` to extract and return format**

In `core/channels/web_server.py`, replace the `_decode_audio` function (lines 70-74):

```python
def _decode_audio(data_url: str) -> tuple[bytes, str]:
    """Decode a base64 data URL to raw bytes and extract audio format.

    Returns:
        Tuple of (audio_bytes, format_extension). Format is extracted from MIME type
        (e.g., 'webm', 'aac', 'wav'). Defaults to 'wav' if no MIME type found.
    """
    fmt = "wav"  # default
    if "," in data_url:
        header, encoded = data_url.split(",", 1)
        # Extract format from "data:audio/webm;base64" or "data:audio/aac;base64"
        if "audio/" in header:
            mime_part = header.split("audio/", 1)[1]
            fmt = mime_part.split(";", 1)[0].split("+", 1)[0].strip()
            # Normalize codecs suffix: "webm;codecs=opus" → "webm"
        return base64.b64decode(encoded), fmt
    return base64.b64decode(data_url), fmt
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/core/channels/test_audio_format.py -v`
Expected: PASS

- [ ] **Step 5: Write failing test for STT `transcribe` accepting format parameter**

```python
# tests/core/voice/test_stt_format.py
from unittest.mock import MagicMock, patch

from core.voice.stt import WhisperSTT


def _make_stt() -> WhisperSTT:
    """Create a WhisperSTT instance with mocked model (skip __init__ model load)."""
    stt = object.__new__(WhisperSTT)
    stt._model = MagicMock()
    return stt


def test_transcribe_uses_correct_suffix_for_aac() -> None:
    """Verify the tempfile suffix matches the audio format."""
    stt = _make_stt()
    with patch.object(stt, "transcribe_file", return_value="hello world"):
        stt.transcribe(b"fake-aac-bytes", language="en", audio_format="aac")
        call_args = stt.transcribe_file.call_args
        # The temp file path should end with .aac
        assert call_args[0][0].endswith(".aac")


def test_transcribe_defaults_to_wav_suffix() -> None:
    """Without audio_format, suffix should be .wav for backward compat."""
    stt = _make_stt()
    with patch.object(stt, "transcribe_file", return_value="hello world"):
        stt.transcribe(b"fake-wav-bytes", language="en")
        call_args = stt.transcribe_file.call_args
        assert call_args[0][0].endswith(".wav")
```

- [ ] **Step 6: Run test to verify it fails**

Run: `python -m pytest tests/core/voice/test_stt_format.py -v`
Expected: FAIL — `transcribe()` doesn't accept `audio_format` parameter

- [ ] **Step 7: Update `WhisperSTT.transcribe` to accept `audio_format`**

In `core/voice/stt.py`, update the `transcribe` method (lines 38-51):

```python
    @traced(name="voice.stt.transcribe")
    def transcribe(
        self, audio_bytes: bytes, language: str = "en", audio_format: str = "wav"
    ) -> str:
        """Transcribe audio bytes to text.

        Args:
            audio_bytes: Raw audio data (WAV, AAC, M4A, WebM, etc.)
            language: Language code for transcription.
            audio_format: File extension hint for ffmpeg (e.g., 'wav', 'aac', 'webm').

        Returns:
            Transcribed text string.
        """
        suffix = f".{audio_format.lstrip('.')}"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
            tmp.write(audio_bytes)
            tmp.flush()
            return self.transcribe_file(tmp.name, language=language)
```

- [ ] **Step 8: Run test to verify it passes**

Run: `python -m pytest tests/core/voice/test_stt_format.py -v`
Expected: PASS

- [ ] **Step 9: Update WebSocket handler to pass format through to STT**

In `core/channels/web_server.py`, update the audio transcription block (around lines 191-196). Change:

```python
                if content_type == "audio" and content:
                    stt = _get_stt()
                    if stt is not None:
                        try:
                            audio_bytes = _decode_audio(content)
                            content = stt.transcribe(audio_bytes)
```

To:

```python
                if content_type == "audio" and content:
                    stt = _get_stt()
                    if stt is not None:
                        try:
                            audio_bytes, audio_fmt = _decode_audio(content)
                            content = stt.transcribe(
                                audio_bytes, audio_format=audio_fmt
                            )
```

- [ ] **Step 10: Run full test suite**

Run: `python -m pytest -x -q`
Expected: All tests pass

- [ ] **Step 11: Lint and type-check**

Run: `ruff check core/channels/ core/voice/ --fix && ruff format core/channels/ core/voice/ && mypy --strict core/channels/ core/voice/`

- [ ] **Step 12: Commit**

```bash
git add core/channels/web_server.py core/voice/stt.py tests/core/channels/test_audio_format.py tests/core/voice/test_stt_format.py
git commit -m "feat: multi-format audio intake (AAC, WAV, WebM, M4A) for iOS support"
```

---

### Task 4: Add `DEVICE_TOKENS_KEY` to `shared/streams.py`

**Files:**
- Modify: `shared/streams.py`
- Test: `tests/shared/test_streams_constants.py` (new or existing)

- [ ] **Step 1: Write test for the new constant**

```python
# tests/shared/test_streams_constants.py
def test_device_tokens_key_exists() -> None:
    from shared.streams import DEVICE_TOKENS_KEY

    assert DEVICE_TOKENS_KEY == "alfred:push:devices"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/shared/test_streams_constants.py -v`
Expected: FAIL — `DEVICE_TOKENS_KEY` not defined

- [ ] **Step 3: Add the constant**

In `shared/streams.py`, add after line 20 (`NOTIFICATION_DISPATCH_STREAM`):

```python
DEVICE_TOKENS_KEY = "alfred:push:devices"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/shared/test_streams_constants.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add shared/streams.py tests/shared/test_streams_constants.py
git commit -m "feat: add DEVICE_TOKENS_KEY constant for APNs device token storage"
```

---

### Task 5: Device Registration Endpoint

**Files:**
- Modify: `core/channels/web_server.py` (add endpoints after onboarding)
- Test: `tests/core/channels/test_device_registration.py` (new)

- [ ] **Step 1: Write failing tests for device registration**

```python
# tests/core/channels/test_device_registration.py
import json
import pytest
from unittest.mock import AsyncMock, patch


@pytest.fixture
def mock_redis():
    mock = AsyncMock()
    mock.hset = AsyncMock()
    mock.hdel = AsyncMock()
    mock.hgetall = AsyncMock(return_value={})
    mock.close = AsyncMock()
    mock.xread = AsyncMock(return_value=[])
    return mock


@pytest.fixture
def app(mock_redis):
    with patch("core.channels.web_server.aioredis") as mock_aioredis:
        mock_aioredis.from_url.return_value = mock_redis
        from core.channels.web_server import create_app

        app = create_app()
        app.state.redis = mock_redis
        yield app


@pytest.fixture
def client(app):
    from fastapi.testclient import TestClient

    return TestClient(app)


def test_register_device_stores_token(client, mock_redis) -> None:
    resp = client.post(
        "/api/devices/register",
        json={
            "device_token": "abc123hex",
            "platform": "ios",
            "identity": "sir",
        },
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
    mock_redis.hset.assert_called_once()
    call_args = mock_redis.hset.call_args
    assert call_args[0][0] == "alfred:push:devices"
    assert call_args[0][1] == "abc123hex"
    stored = json.loads(call_args[0][2])
    assert stored["platform"] == "ios"
    assert stored["identity"] == "sir"
    assert "registered_at" in stored


def test_unregister_device_removes_token(client, mock_redis) -> None:
    resp = client.request(
        "DELETE",
        "/api/devices/register",
        json={"device_token": "abc123hex"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
    mock_redis.hdel.assert_called_once_with("alfred:push:devices", "abc123hex")


def test_register_device_missing_token_returns_422(client, mock_redis) -> None:
    resp = client.post(
        "/api/devices/register",
        json={"platform": "ios", "identity": "sir"},
    )
    assert resp.status_code == 422
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/core/channels/test_device_registration.py -v`
Expected: FAIL — endpoint doesn't exist (404)

- [ ] **Step 3: Implement device registration endpoints**

In `core/channels/web_server.py`, add these Pydantic models after the `OnboardingPayload` class:

```python
class DeviceRegistration(BaseModel):
    """APNs device token registration."""

    device_token: str
    platform: str
    identity: str


class DeviceUnregistration(BaseModel):
    """APNs device token removal."""

    device_token: str
```

Add these endpoints inside `create_app()`, after the `save_onboarding` endpoint:

```python
    @app.post("/api/devices/register")
    async def register_device(payload: DeviceRegistration) -> dict[str, str]:
        """Register an APNs device token for push notifications."""
        import json
        from datetime import UTC, datetime

        from shared.streams import DEVICE_TOKENS_KEY

        r: aioredis.Redis[Any] = app.state.redis  # type: ignore[type-arg]
        value = json.dumps(
            {
                "platform": payload.platform,
                "identity": payload.identity,
                "registered_at": datetime.now(UTC).isoformat(),
            }
        )
        await r.hset(DEVICE_TOKENS_KEY, payload.device_token, value)  # type: ignore[misc]
        logger.info("Registered device token (platform={})", payload.platform)
        return {"status": "ok"}

    @app.delete("/api/devices/register")
    async def unregister_device(payload: DeviceUnregistration) -> dict[str, str]:
        """Remove an APNs device token."""
        from shared.streams import DEVICE_TOKENS_KEY

        r: aioredis.Redis[Any] = app.state.redis  # type: ignore[type-arg]
        await r.hdel(DEVICE_TOKENS_KEY, payload.device_token)  # type: ignore[misc]
        logger.info("Unregistered device token")
        return {"status": "ok"}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/core/channels/test_device_registration.py -v`
Expected: PASS

- [ ] **Step 5: Lint and type-check**

Run: `ruff check core/channels/web_server.py --fix && ruff format core/channels/web_server.py && mypy --strict core/channels/`

- [ ] **Step 6: Commit**

```bash
git add core/channels/web_server.py tests/core/channels/test_device_registration.py
git commit -m "feat: device registration endpoints for APNs push notifications"
```

---

### Task 6: APNs Delivery Adapter

**Files:**
- Create: `core/notifications/adapters/apns.py`
- Test: `tests/core/notifications/test_apns_adapter.py` (new)

- [ ] **Step 1: Write failing tests for the APNs adapter**

```python
# tests/core/notifications/test_apns_adapter.py
import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from core.notifications.schema import Notification, Urgency


@pytest.fixture
def mock_redis() -> AsyncMock:
    r = AsyncMock()
    r.hgetall = AsyncMock(
        return_value={
            b"abc123": json.dumps(
                {"platform": "ios", "identity": "sir", "registered_at": "2026-04-03T00:00:00Z"}
            ).encode(),
        }
    )
    return r


@pytest.fixture
def notification() -> Notification:
    return Notification(
        title="Test Alert",
        body="Something happened",
        urgency=Urgency.IMPORTANT,
        source="test",
    )


async def test_apns_adapter_sends_to_registered_devices(
    mock_redis: AsyncMock, notification: Notification
) -> None:
    from core.notifications.adapters.apns import APNsChannelAdapter

    mock_client = AsyncMock()
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_client.post = AsyncMock(return_value=mock_response)

    adapter = APNsChannelAdapter(
        redis=mock_redis,
        team_id="TEAM123",
        key_id="KEY456",
        private_key="fake-key-content",
        bundle_id="com.alfred.app",
    )
    adapter._client = mock_client

    await adapter.deliver(notification)

    mock_client.post.assert_called_once()
    call_args = mock_client.post.call_args
    # Verify APNs URL contains the device token
    assert "abc123" in call_args[0][0]
    # Verify payload structure
    payload = json.loads(call_args[1]["content"])
    assert payload["aps"]["alert"]["title"] == "Test Alert"
    assert payload["aps"]["alert"]["body"] == "Something happened"
    assert payload["aps"]["sound"] == "default"
    assert payload["aps"]["interruption-level"] == "active"


async def test_apns_adapter_informational_no_sound(
    mock_redis: AsyncMock,
) -> None:
    from core.notifications.adapters.apns import APNsChannelAdapter

    notif = Notification(
        title="FYI",
        body="Info",
        urgency=Urgency.INFORMATIONAL,
        source="test",
    )

    mock_client = AsyncMock()
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_client.post = AsyncMock(return_value=mock_response)

    adapter = APNsChannelAdapter(
        redis=mock_redis,
        team_id="T",
        key_id="K",
        private_key="pk",
        bundle_id="com.alfred.app",
    )
    adapter._client = mock_client

    await adapter.deliver(notif)

    payload = json.loads(mock_client.post.call_args[1]["content"])
    assert payload["aps"].get("sound") is None
    assert payload["aps"]["interruption-level"] == "passive"


async def test_apns_adapter_urgent_critical_alert(
    mock_redis: AsyncMock,
) -> None:
    from core.notifications.adapters.apns import APNsChannelAdapter

    notif = Notification(
        title="URGENT",
        body="Critical",
        urgency=Urgency.URGENT,
        source="test",
    )

    mock_client = AsyncMock()
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_client.post = AsyncMock(return_value=mock_response)

    adapter = APNsChannelAdapter(
        redis=mock_redis,
        team_id="T",
        key_id="K",
        private_key="pk",
        bundle_id="com.alfred.app",
    )
    adapter._client = mock_client

    await adapter.deliver(notif)

    payload = json.loads(mock_client.post.call_args[1]["content"])
    assert payload["aps"]["sound"] == {"critical": 1, "name": "default", "volume": 1.0}
    assert payload["aps"]["interruption-level"] == "critical"


async def test_apns_adapter_skips_when_no_devices(notification: Notification) -> None:
    from core.notifications.adapters.apns import APNsChannelAdapter

    empty_redis = AsyncMock()
    empty_redis.hgetall = AsyncMock(return_value={})

    mock_client = AsyncMock()
    adapter = APNsChannelAdapter(
        redis=empty_redis,
        team_id="T",
        key_id="K",
        private_key="pk",
        bundle_id="com.alfred.app",
    )
    adapter._client = mock_client

    await adapter.deliver(notification)

    mock_client.post.assert_not_called()


def test_apns_adapter_supports_all_urgencies() -> None:
    from core.notifications.adapters.apns import APNsChannelAdapter

    adapter = APNsChannelAdapter.__new__(APNsChannelAdapter)
    assert adapter.supports_urgency(Urgency.INFORMATIONAL)
    assert adapter.supports_urgency(Urgency.IMPORTANT)
    assert adapter.supports_urgency(Urgency.URGENT)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/core/notifications/test_apns_adapter.py -v`
Expected: FAIL — module not found

- [ ] **Step 3: Implement APNs adapter**

```python
# core/notifications/adapters/apns.py
"""APNs channel adapter — pushes notifications to iOS devices via Apple Push Notification service."""

from __future__ import annotations

import json
import time
from typing import TYPE_CHECKING, Any, ClassVar

import jwt  # PyJWT[crypto] — must be added to pyproject.toml

from loguru import logger

from core.notifications.channels import ChannelAdapter, ChannelRegistry
from core.notifications.schema import Notification, Urgency
from shared.streams import DEVICE_TOKENS_KEY

if TYPE_CHECKING:
    import httpx
    import redis.asyncio as aioredis

APNS_PRODUCTION_URL = "https://api.push.apple.com"
APNS_SANDBOX_URL = "https://api.sandbox.push.apple.com"


@ChannelRegistry.register()
class APNsChannelAdapter(ChannelAdapter):
    """Push notifications to iOS devices via APNs HTTP/2 API."""

    name: ClassVar[str] = "apns"
    supported_urgencies: ClassVar[set[Urgency]] = {
        Urgency.INFORMATIONAL,
        Urgency.IMPORTANT,
        Urgency.URGENT,
    }

    def __init__(
        self,
        redis: aioredis.Redis[Any],  # type: ignore[type-arg]
        team_id: str,
        key_id: str,
        private_key: str,
        bundle_id: str,
        sandbox: bool = False,
    ) -> None:
        self._redis = redis
        self._team_id = team_id
        self._key_id = key_id
        self._private_key = private_key
        self._bundle_id = bundle_id
        self._base_url = APNS_SANDBOX_URL if sandbox else APNS_PRODUCTION_URL
        self._client: httpx.AsyncClient | None = None
        self._token: str | None = None
        self._token_expires: float = 0

    async def _ensure_client(self) -> httpx.AsyncClient:
        """Lazy-init httpx client with HTTP/2 support."""
        if self._client is None:
            import httpx

            self._client = httpx.AsyncClient(http2=True, timeout=10.0)
        return self._client

    def _get_auth_token(self) -> str:
        """Generate or reuse a JWT for APNs authentication.

        Tokens are valid for up to 60 minutes. We refresh at 50 minutes.
        """
        now = time.time()
        if self._token and now < self._token_expires:
            return self._token

        payload = {
            "iss": self._team_id,
            "iat": int(now),
        }
        self._token = jwt.encode(payload, self._private_key, algorithm="ES256", headers={
            "alg": "ES256",
            "kid": self._key_id,
        })
        self._token_expires = now + 3000  # refresh after 50 minutes
        return self._token

    def _build_payload(self, notification: Notification) -> dict[str, Any]:
        """Build the APNs JSON payload based on urgency."""
        aps: dict[str, Any] = {
            "alert": {
                "title": notification.title,
                "body": notification.body,
            },
        }

        if notification.urgency == Urgency.INFORMATIONAL:
            aps["interruption-level"] = "passive"
        elif notification.urgency == Urgency.IMPORTANT:
            aps["sound"] = "default"
            aps["interruption-level"] = "active"
        elif notification.urgency == Urgency.URGENT:
            aps["sound"] = {"critical": 1, "name": "default", "volume": 1.0}
            aps["interruption-level"] = "critical"

        return {
            "aps": aps,
            "notification_id": notification.notification_id,
        }

    async def deliver(self, notification: Notification) -> None:
        """Deliver notification to all registered iOS devices."""
        raw_tokens: dict[bytes, bytes] = await self._redis.hgetall(DEVICE_TOKENS_KEY)  # type: ignore[misc]
        if not raw_tokens:
            logger.debug("APNsChannelAdapter: no registered devices, skipping")
            return

        client = await self._ensure_client()
        token = self._get_auth_token()
        payload = self._build_payload(notification)
        payload_bytes = json.dumps(payload)

        priority = "5" if notification.urgency == Urgency.INFORMATIONAL else "10"
        headers = {
            "authorization": f"bearer {token}",
            "apns-topic": self._bundle_id,
            "apns-push-type": "alert",
            "apns-priority": priority,
        }

        for device_token_bytes, _info in raw_tokens.items():
            device_token = (
                device_token_bytes.decode()
                if isinstance(device_token_bytes, bytes)
                else device_token_bytes
            )
            url = f"{self._base_url}/3/device/{device_token}"
            try:
                resp = await client.post(url, content=payload_bytes, headers=headers)
                if resp.status_code != 200:
                    logger.warning(
                        "APNs delivery failed for token {}: {} {}",
                        device_token[:8],
                        resp.status_code,
                        resp.text,
                    )
                else:
                    logger.info(
                        "APNs notification sent (token={}..., urgency={})",
                        device_token[:8],
                        notification.urgency.value,
                    )
            except Exception as exc:
                logger.error("APNs delivery error for token {}: {}", device_token[:8], exc)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/core/notifications/test_apns_adapter.py -v`
Expected: PASS

- [ ] **Step 5: Add PyJWT and httpx[http2] to project dependencies**

PyJWT is NOT in the current dependency tree — it must be added. The `[crypto]` extra pulls in `cryptography` for ES256 (APNs requires this). Also upgrade `httpx` to `httpx[http2]` for HTTP/2 support (required by APNs). Add a mypy override for `jwt.*` since PyJWT lacks complete type stubs.

In `pyproject.toml`:
- Add `"PyJWT[crypto]>=2.0"` to `dependencies`
- Change `"httpx>=0.27"` to `"httpx[http2]>=0.27"`
- Add to `[tool.mypy]`: `[[tool.mypy.overrides]]` with `module = "jwt.*"` and `ignore_missing_imports = true`

Run: `uv pip install -e ".[dev,memory,voice,integrations]"` to install the new deps.

- [ ] **Step 6: Lint and type-check**

Run: `ruff check core/notifications/adapters/apns.py --fix && ruff format core/notifications/adapters/apns.py && mypy --strict core/notifications/`

- [ ] **Step 7: Run full test suite**

Run: `python -m pytest -x -q`
Expected: All tests pass

- [ ] **Step 8: Commit**

```bash
git add core/notifications/adapters/apns.py tests/core/notifications/test_apns_adapter.py pyproject.toml
git commit -m "feat: APNs delivery adapter for iOS push notifications"
```

---

### Task 7: Wire APNs Adapter into Channels Process

**Files:**
- Modify: `core/channels/web_server.py` (inside `_lifespan()`)
- Test: integration-level (manual — verify adapter is registered at startup)

> **Note:** The APNs adapter needs Redis access for device token lookups. Redis is only available inside the FastAPI `_lifespan()` function (stored as `app.state.redis`), NOT in `__main__.py`. Therefore, wiring must happen inside `_lifespan()` in `web_server.py`, alongside the existing delivery worker startup.
>
> **Broadcast model:** The notification dispatch system routes ALL notifications to ALL adapters that support the urgency level. The APNs adapter fires for every notification, does `hgetall` to find device tokens, and skips if none are registered. This is correct for a single-user system.

- [ ] **Step 1: Read `core/channels/web_server.py` `_lifespan()` to understand current wiring**

Read the `_lifespan()` function to see where Redis is initialized and where delivery workers start.

- [ ] **Step 2: Add APNs adapter registration inside `_lifespan()`**

In `core/channels/web_server.py`, inside the `_lifespan()` function, after Redis is initialized (`app.state.redis = ...`) and before `yield`, add:

```python
    # APNs adapter for iOS push notifications (requires credentials in Secrets Manager)
    try:
        from shared.secrets import get_secret

        apns_team_id = get_secret("apns", "team_id")
        apns_key_id = get_secret("apns", "key_id")
        apns_private_key = get_secret("apns", "private_key")
        apns_bundle_id = get_secret("apns", "bundle_id")

        if (
            apns_team_id is not None
            and apns_key_id is not None
            and apns_private_key is not None
            and apns_bundle_id is not None
        ):
            import core.notifications.adapters.apns  # noqa: F401 — trigger @register
            from core.notifications.adapters.apns import APNsChannelAdapter
            from core.notifications.channels import ChannelRegistry

            apns_adapter = APNsChannelAdapter(
                redis=app.state.redis,
                team_id=apns_team_id,
                key_id=apns_key_id,
                private_key=apns_private_key,
                bundle_id=apns_bundle_id,
            )
            ChannelRegistry.set_instance("apns", apns_adapter)
            logger.info("APNs adapter registered")
        else:
            logger.info("APNs credentials not configured, skipping adapter")
    except Exception as exc:
        logger.warning("APNs adapter init failed: {}", exc)
```

- [ ] **Step 3: Run full test suite**

Run: `python -m pytest -x -q`
Expected: All tests pass (APNs adapter is optional — missing credentials skip gracefully)

- [ ] **Step 4: Commit**

```bash
git add core/channels/web_server.py
git commit -m "feat: wire APNs adapter into channels process startup"
```

---

### Task 8: Add `notification_id` to WebSocket Notification Payload

The iOS app needs `notification_id` in WebSocket notification messages for deduplication with APNs. The existing WebSocket adapter sends `{type, title, body, urgency}` but omits the ID.

**Files:**
- Modify: `core/notifications/adapters/websocket.py:37-42`
- Test: `tests/core/notifications/test_websocket_adapter.py` (existing or new)

- [ ] **Step 1: Write test for notification_id in payload**

```python
# tests/core/notifications/test_ws_notification_id.py
from unittest.mock import AsyncMock

from core.notifications.schema import Notification, Urgency


async def test_websocket_payload_includes_notification_id() -> None:
    from core.notifications.adapters.websocket import WebSocketChannelAdapter

    mock_ws = AsyncMock()
    adapter = WebSocketChannelAdapter(get_sessions=lambda: [mock_ws])

    notif = Notification(
        title="Test",
        body="Body",
        urgency=Urgency.IMPORTANT,
        source="test",
    )

    await adapter.deliver(notif)

    mock_ws.send_json.assert_called_once()
    payload = mock_ws.send_json.call_args[0][0]
    assert payload["notification_id"] == notif.notification_id
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/core/notifications/test_ws_notification_id.py -v`
Expected: FAIL — `notification_id` not in payload

- [ ] **Step 3: Add `notification_id` to WebSocket adapter payload**

In `core/notifications/adapters/websocket.py`, change the payload dict (lines 37-42):

```python
        payload = {
            "type": "notification",
            "title": notification.title,
            "body": notification.body,
            "urgency": notification.urgency.value,
            "notification_id": notification.notification_id,
        }
```

- [ ] **Step 4: Run tests**

Run: `python -m pytest tests/core/notifications/test_ws_notification_id.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/notifications/adapters/websocket.py tests/core/notifications/test_ws_notification_id.py
git commit -m "feat: include notification_id in WebSocket payload for iOS deduplication"
```

---

### Task 9: Final Validation

- [ ] **Step 1: Run full lint + format**

Run: `ruff check . --fix && ruff format .`

- [ ] **Step 2: Run full type check**

Run: `mypy --strict bus/ core/ shared/`

- [ ] **Step 3: Run full test suite**

Run: `python -m pytest -x -q`

- [ ] **Step 4: Verify test count increased**

Expected: Previous baseline was 730 tests. Should now have ~750+ tests.

- [ ] **Step 5: Commit any remaining fixes**

```bash
git add -A
git commit -m "chore: final lint and type fixes for iOS server-side support"
```
