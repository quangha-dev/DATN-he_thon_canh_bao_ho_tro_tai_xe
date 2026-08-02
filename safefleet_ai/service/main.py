from __future__ import annotations

import os
import re
import json
import logging
import urllib.request
from pathlib import Path
from enum import Enum
from typing import Any

from fastapi import FastAPI
from pydantic import BaseModel, Field

LOGGER = logging.getLogger("safefleet.ai")


class Intent(str, Enum):
    START_TRIP = "START_TRIP"
    PAUSE_TRIP = "PAUSE_TRIP"
    RESUME_TRIP = "RESUME_TRIP"
    COMPLETE_TRIP = "COMPLETE_TRIP"
    GET_DRIVING_TIME = "GET_DRIVING_TIME"
    REPORT_FLOOD = "REPORT_FLOOD"
    SEND_SOS = "SEND_SOS"
    READ_LATEST_WARNING = "READ_LATEST_WARNING"
    UNKNOWN = "UNKNOWN"


class IntentRequest(BaseModel):
    transcript: str = Field(min_length=1, max_length=1000)


class IntentResponse(BaseModel):
    intent: Intent
    confidence: float
    requires_confirmation: bool
    source: str = "LOCAL_RULE"


class ChatMessage(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=20)


class ChatResponse(BaseModel):
    response_text: str
    model: str
    source: str


RULES: list[tuple[Intent, tuple[str, ...], bool]] = [
    (Intent.SEND_SOS, ("sos", "cứu hộ", "cuu ho", "khẩn cấp", "khan cap"), True),
    (
        Intent.REPORT_FLOOD,
        ("báo ngập", "bao ngap", "điểm ngập", "diem ngap", "đang ngập", "dang ngap"),
        True,
    ),
    (Intent.PAUSE_TRIP, ("tạm dừng", "tam dung", "tạm nghỉ", "tam nghi"), True),
    (Intent.RESUME_TRIP, ("tiếp tục", "tiep tuc"), True),
    (Intent.COMPLETE_TRIP, ("hoàn thành", "hoan thanh", "kết thúc chuyến", "ket thuc chuyen"), True),
    (Intent.START_TRIP, ("bắt đầu chuyến", "bat dau chuyen", "khởi hành", "khoi hanh"), True),
    (
        Intent.GET_DRIVING_TIME,
        (
            "giờ lái",
            "gio lai",
            "còn lái",
            "con lai",
            "lái bao lâu",
            "lai bao lau",
            "thời gian lái",
            "thoi gian lai",
        ),
        False,
    ),
    (Intent.READ_LATEST_WARNING, ("cảnh báo mới", "canh bao moi", "đọc cảnh báo", "doc canh bao"), False),
]

CONFIRMATION_REQUIRED = {
    Intent.START_TRIP,
    Intent.PAUSE_TRIP,
    Intent.RESUME_TRIP,
    Intent.COMPLETE_TRIP,
    Intent.REPORT_FLOOD,
    Intent.SEND_SOS,
}

INTENT_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "intent": {
            "type": "string",
            "enum": [intent.value for intent in Intent],
        },
        "confidence": {
            "type": "number",
            "minimum": 0,
            "maximum": 1,
        },
    },
    "required": ["intent", "confidence"],
    "additionalProperties": False,
}


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def classify(transcript: str) -> IntentResponse:
    normalized = normalize(transcript)
    for intent, phrases, confirmation in RULES:
        if any(phrase in normalized for phrase in phrases):
            return IntentResponse(
                intent=intent,
                confidence=0.95,
                requires_confirmation=confirmation,
            )
    return IntentResponse(
        intent=Intent.UNKNOWN,
        confidence=0.0,
        requires_confirmation=False,
    )


def _response_text(payload: dict[str, Any]) -> str:
    direct = payload.get("output_text")
    if isinstance(direct, str) and direct.strip():
        return direct
    for output in payload.get("output", []):
        if not isinstance(output, dict):
            continue
        for content in output.get("content", []):
            if isinstance(content, dict) and content.get("type") == "output_text":
                text = content.get("text")
                if isinstance(text, str) and text.strip():
                    return text
    raise ValueError("OpenAI response không có output_text")


def classify_with_openai(transcript: str) -> IntentResponse | None:
    if os.getenv("OPENAI_ENABLED", "false").lower() != "true":
        return None
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        return None

    base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    timeout_seconds = float(os.getenv("OPENAI_TIMEOUT_SECONDS", "8"))
    request_payload = {
        "model": model,
        "store": False,
        "instructions": (
            "Phân loại đúng một intent SafeFleet. Không thực thi hành động, không tạo SQL, "
            "không thay đổi tài xế/chuyến. Nếu không chắc, trả UNKNOWN."
        ),
        "input": transcript,
        "text": {
            "format": {
                "type": "json_schema",
                "name": "safefleet_intent",
                "strict": True,
                "schema": INTENT_SCHEMA,
            }
        },
        "max_output_tokens": 200,
    }
    request = urllib.request.Request(
        f"{base_url}/responses",
        data=json.dumps(request_payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            response_payload = json.loads(response.read().decode("utf-8"))
        structured = json.loads(_response_text(response_payload))
        intent = Intent(structured["intent"])
        confidence = min(1.0, max(0.0, float(structured["confidence"])))
        return IntentResponse(
            intent=intent,
            confidence=confidence,
            requires_confirmation=intent in CONFIRMATION_REQUIRED,
            source="OPENAI",
        )
    except Exception as exception:
        LOGGER.warning(
            "OpenAI intent fallback failed; returning deterministic UNKNOWN (%s)",
            type(exception).__name__,
        )
        return None


app = FastAPI(
    title="SafeFleet AI Service",
    version="0.1.0",
    description="Server-side intent fallback and model metadata; realtime cabin AI stays on-device.",
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "UP"}


@app.get("/models/metadata")
def model_metadata() -> dict[str, object]:
    metadata_path = Path(os.getenv("MODEL_DIR", "models")) / "safefleet_temporal_rules.json"
    on_device: dict[str, object] | None = None
    if metadata_path.is_file():
        on_device = json.loads(metadata_path.read_text(encoding="utf-8"))
    return {
        "serviceVersion": app.version,
        "modelVersion": os.getenv("MODEL_VERSION", "local-rules-v1"),
        "realtimeCameraProcessing": False,
        "onDeviceCabinModel": on_device,
        "openAiEnabled": os.getenv("OPENAI_ENABLED", "false").lower() == "true",
        "supportedIntents": [intent.value for intent in Intent if intent is not Intent.UNKNOWN],
    }


@app.post("/intent/classify", response_model=IntentResponse)
def classify_intent(request: IntentRequest) -> IntentResponse:
    local = classify(request.transcript)
    if local.intent is not Intent.UNKNOWN:
        return local
    return classify_with_openai(request.transcript) or local


def chat_with_openai(messages: list[ChatMessage]) -> ChatResponse | None:
    if os.getenv("OPENAI_ENABLED", "false").lower() != "true":
        return None
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        return None
    base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    request_payload = {
        "model": model,
        "store": False,
        "instructions": (
            "Bạn là trợ lý giọng nói SafeFleet dành cho tài xế Việt Nam. Trả lời ngắn, rõ, "
            "ưu tiên an toàn và không khuyến khích thao tác màn hình khi xe chạy. Không được tuyên bố "
            "đã gửi SOS, báo ngập hay thay đổi chuyến; các hành động đó phải dùng luồng lệnh xác nhận riêng."
        ),
        "input": [message.model_dump() for message in messages],
        "max_output_tokens": 500,
    }
    request = urllib.request.Request(
        f"{base_url}/responses",
        data=json.dumps(request_payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(
            request,
            timeout=float(os.getenv("OPENAI_TIMEOUT_SECONDS", "12")),
        ) as response:
            payload = json.loads(response.read().decode("utf-8"))
        return ChatResponse(
            response_text=_response_text(payload).strip(),
            model=model,
            source="OPENAI",
        )
    except Exception as exception:
        LOGGER.warning("OpenAI chat failed (%s)", type(exception).__name__)
        return None


@app.post("/chat/respond", response_model=ChatResponse)
def chat_respond(request: ChatRequest) -> ChatResponse:
    generated = chat_with_openai(request.messages)
    if generated is not None:
        return generated
    latest = request.messages[-1].content.lower()
    if any(word in latest for word in ("sos", "khẩn cấp", "cứu hộ")):
        text = "Tình huống có vẻ khẩn cấp. Hãy dùng lệnh SOS và xác nhận để gửi vị trí đến điều phối."
    elif "ngập" in latest:
        text = "Bạn có thể mở Bản đồ để tìm tuyến né ngập hoặc dùng lệnh báo ngập có xác nhận."
    else:
        text = "Tôi đang ở chế độ ngoại tuyến. Tôi vẫn có thể hỗ trợ lệnh SOS, báo ngập, dẫn đường và đọc cảnh báo."
    return ChatResponse(response_text=text, model="local-safe-fallback", source="LOCAL_FALLBACK")
