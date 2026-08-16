from __future__ import annotations

import json
import os
from pathlib import Path

from fastapi import APIRouter, Depends

from service.api.dependencies import configuration_store
from service.core.security import require_internal_service
from service.intent.models import Intent

router = APIRouter(
    prefix="/models",
    tags=["models"],
    dependencies=[Depends(require_internal_service)],
)


@router.get("/metadata")
def metadata() -> dict[str, object]:
    metadata_path = Path(os.getenv("MODEL_DIR", "models")) / "safefleet_temporal_rules.json"
    on_device: dict[str, object] | None = None
    if metadata_path.is_file():
        on_device = json.loads(metadata_path.read_text(encoding="utf-8"))
    runtime = configuration_store().runtime()
    return {
        "serviceVersion": "0.2.0",
        "modelVersion": os.getenv("MODEL_VERSION", "local-rules-v1"),
        "realtimeCameraProcessing": False,
        "onDeviceCabinModel": on_device,
        "openAiEnabled": runtime.enabled and bool(runtime.api_key),
        "supportedIntents": [intent.value for intent in Intent if intent is not Intent.UNKNOWN],
    }
