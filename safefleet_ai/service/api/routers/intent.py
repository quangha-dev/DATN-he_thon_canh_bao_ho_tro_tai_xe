from fastapi import APIRouter, Depends

from service.api.dependencies import intent_service
from service.core.security import require_internal_service
from service.intent.models import IntentRequest, IntentResponse

router = APIRouter(
    prefix="/intent",
    tags=["intent"],
    dependencies=[Depends(require_internal_service)],
)


@router.post("/classify", response_model=IntentResponse)
def classify(request: IntentRequest) -> IntentResponse:
    return intent_service().classify(request.transcript)
