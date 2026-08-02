from fastapi.testclient import TestClient

import json

from service.main import Intent, app


client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "UP"}


def test_sos_requires_confirmation() -> None:
    response = client.post("/intent/classify", json={"transcript": "Tôi cần cứu hộ khẩn cấp"})
    assert response.status_code == 200
    assert response.json()["intent"] == Intent.SEND_SOS
    assert response.json()["requires_confirmation"] is True


def test_natural_vietnamese_flood_and_driving_time_phrases() -> None:
    flood = client.post(
        "/intent/classify",
        json={"transcript": "Đường phía trước đang ngập"},
    )
    driving_time = client.post(
        "/intent/classify",
        json={"transcript": "Tôi còn được lái bao lâu"},
    )

    assert flood.json()["intent"] == Intent.REPORT_FLOOD
    assert flood.json()["requires_confirmation"] is True
    assert driving_time.json()["intent"] == Intent.GET_DRIVING_TIME
    assert driving_time.json()["requires_confirmation"] is False


def test_unknown_does_not_execute_action() -> None:
    response = client.post("/intent/classify", json={"transcript": "Mở nhạc"})
    assert response.status_code == 200
    assert response.json()["intent"] == Intent.UNKNOWN
    assert response.json()["requires_confirmation"] is False


def test_metadata_exposes_on_device_contract_without_server_camera_processing() -> None:
    response = client.get("/models/metadata")
    assert response.status_code == 200
    metadata = response.json()
    assert metadata["realtimeCameraProcessing"] is False
    assert metadata["onDeviceCabinModel"]["runtime"] == "on-device"


def test_unknown_uses_structured_openai_fallback_without_executing_action(
    monkeypatch,
) -> None:
    captured: dict[str, object] = {}

    class FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def read(self) -> bytes:
            return json.dumps(
                {
                    "output": [
                        {
                            "content": [
                                {
                                    "type": "output_text",
                                    "text": json.dumps(
                                        {
                                            "intent": "COMPLETE_TRIP",
                                            "confidence": 0.88,
                                        }
                                    ),
                                }
                            ]
                        }
                    ]
                }
            ).encode()

    def fake_urlopen(request, timeout):
        captured["url"] = request.full_url
        captured["authorization"] = request.headers["Authorization"]
        captured["timeout"] = timeout
        captured["payload"] = json.loads(request.data)
        return FakeResponse()

    monkeypatch.setenv("OPENAI_ENABLED", "true")
    monkeypatch.setenv("OPENAI_API_KEY", "test-api-key-not-real")
    monkeypatch.setenv("OPENAI_BASE_URL", "https://api.openai.test/v1")
    monkeypatch.setenv("OPENAI_MODEL", "gpt-5.6-luna")
    monkeypatch.setattr("service.main.urllib.request.urlopen", fake_urlopen)

    response = client.post(
        "/intent/classify",
        json={"transcript": "Tôi đã tới nơi, xử lý giúp tôi"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "intent": "COMPLETE_TRIP",
        "confidence": 0.88,
        "requires_confirmation": True,
        "source": "OPENAI",
    }
    assert captured["url"] == "https://api.openai.test/v1/responses"
    assert captured["authorization"] == "Bearer test-api-key-not-real"
    assert captured["payload"]["store"] is False
    assert captured["payload"]["text"]["format"]["strict"] is True


def test_openai_failure_falls_back_to_safe_unknown(monkeypatch) -> None:
    monkeypatch.setenv("OPENAI_ENABLED", "true")
    monkeypatch.setenv("OPENAI_API_KEY", "test-api-key-not-real")

    def fail(*_args, **_kwargs):
        raise TimeoutError

    monkeypatch.setattr("service.main.urllib.request.urlopen", fail)
    response = client.post("/intent/classify", json={"transcript": "Mở nhạc"})

    assert response.status_code == 200
    assert response.json()["intent"] == "UNKNOWN"
    assert response.json()["requires_confirmation"] is False
    assert response.json()["source"] == "LOCAL_RULE"


def test_chat_has_safe_local_fallback(monkeypatch) -> None:
    monkeypatch.setenv("OPENAI_ENABLED", "false")
    response = client.post(
        "/chat/respond",
        json={"messages": [{"role": "user", "content": "Đường phía trước bị ngập"}]},
    )
    assert response.status_code == 200
    assert response.json()["source"] == "LOCAL_FALLBACK"
    assert "Bản đồ" in response.json()["response_text"]
