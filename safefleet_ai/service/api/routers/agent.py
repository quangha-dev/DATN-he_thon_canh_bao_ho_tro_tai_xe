from fastapi import APIRouter, Depends, HTTPException

from service.agent.configuration import ConfigurationError
from service.agent.models import (
    AgentChatRequest,
    AgentChatResponse,
    AgentConfigurationResponse,
    AgentConfigurationUpdate,
)
from service.api.dependencies import agent_orchestrator, configuration_store
from service.core.security import require_internal_service, require_user_authorization
from service.providers.openai import OpenAiClient, OpenAiError

router = APIRouter(prefix="/agent", tags=["agent"], dependencies=[Depends(require_internal_service)])


@router.post("/respond", response_model=AgentChatResponse, response_model_by_alias=True)
def respond(
    request: AgentChatRequest,
    user_authorization: str = Depends(require_user_authorization),
) -> AgentChatResponse:
    return agent_orchestrator().respond(request, user_authorization)


@router.get("/config", response_model=AgentConfigurationResponse, response_model_by_alias=True)
def get_configuration() -> AgentConfigurationResponse:
    try:
        return configuration_store().public()
    except ConfigurationError as exception:
        raise HTTPException(status_code=500, detail=str(exception)) from exception


@router.put("/config", response_model=AgentConfigurationResponse, response_model_by_alias=True)
def update_configuration(request: AgentConfigurationUpdate) -> AgentConfigurationResponse:
    try:
        return configuration_store().update(request)
    except ConfigurationError as exception:
        raise HTTPException(status_code=400, detail=str(exception)) from exception


@router.post("/config/test")
def test_configuration() -> dict[str, str]:
    try:
        OpenAiClient().test_connection(configuration_store().runtime())
    except (ConfigurationError, OpenAiError) as exception:
        raise HTTPException(status_code=502, detail=str(exception)) from exception
    return {"status": "OK", "message": "Kết nối OpenAI gpt-4o-mini thành công"}
