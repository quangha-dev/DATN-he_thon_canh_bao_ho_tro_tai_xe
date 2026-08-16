from __future__ import annotations

import logging
from typing import Any

from service.agent.configuration import AgentConfigurationStore
from service.intent.models import Intent, IntentResponse
from service.intent.rules import CONFIRMATION_REQUIRED, classify_locally
from service.providers.openai import OpenAiClient, OpenAiError

LOGGER = logging.getLogger("safefleet.ai.intent")

INTENT_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "intent": {"type": "string", "enum": [intent.value for intent in Intent]},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
    },
    "required": ["intent", "confidence"],
    "additionalProperties": False,
}


class IntentClassificationService:
    def __init__(self, configuration_store: AgentConfigurationStore, openai: OpenAiClient | None = None):
        self._configuration_store = configuration_store
        self._openai = openai or OpenAiClient()

    def classify(self, transcript: str) -> IntentResponse:
        local = classify_locally(transcript)
        if local.intent is not Intent.UNKNOWN:
            return local
        configuration = self._configuration_store.runtime()
        if not configuration.enabled or not configuration.api_key:
            return local
        try:
            structured = self._openai.structured_response(
                configuration,
                instructions=(
                    "Phân loại đúng một intent SafeFleet. Không thực thi hành động, không tạo SQL, "
                    "không thay đổi tài xế/chuyến. Nếu không chắc, trả UNKNOWN."
                ),
                input_text=transcript,
                schema_name="safefleet_intent",
                schema=INTENT_SCHEMA,
                max_output_tokens=200,
            )
            intent = Intent(structured["intent"])
            confidence = min(1.0, max(0.0, float(structured["confidence"])))
            return IntentResponse(
                intent=intent,
                confidence=confidence,
                requires_confirmation=intent in CONFIRMATION_REQUIRED,
                source="OPENAI",
            )
        except (OpenAiError, KeyError, TypeError, ValueError) as exception:
            LOGGER.warning("OpenAI intent fallback failed (%s)", type(exception).__name__)
            return local
