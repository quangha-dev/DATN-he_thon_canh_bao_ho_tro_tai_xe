from fastapi import APIRouter, Depends

from service.api.dependencies import chat_service
from service.chat.models import ChatRequest, ChatResponse
from service.core.security import require_internal_service

router = APIRouter(
    prefix="/chat",
    tags=["chat"],
    dependencies=[Depends(require_internal_service)],
)


@router.post("/respond", response_model=ChatResponse)
def respond(request: ChatRequest) -> ChatResponse:
    return chat_service().respond(request.messages)
