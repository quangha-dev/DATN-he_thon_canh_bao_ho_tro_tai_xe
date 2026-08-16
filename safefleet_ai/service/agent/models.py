from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


def _camel(value: str) -> str:
    head, *tail = value.split("_")
    return head + "".join(part.capitalize() for part in tail)


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=_camel, populate_by_name=True)


class ChatMessage(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=4000)


class AgentChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=20)


class AgentStep(CamelModel):
    index: int
    tool: str
    arguments: str
    success: bool
    plan_check: str
    reason: str


class AgentClientAction(CamelModel):
    type: str
    destination: str
    trip_id: int | None = None


class AgentConfirmationRequest(CamelModel):
    type: str
    action: str
    trip_id: int
    note: str | None = None
    prompt: str


class AgentChatResponse(CamelModel):
    response_text: str
    model: str
    source: str = "SAFEFLEET_AI"
    status: str
    plan: list[str] = Field(default_factory=list)
    steps: list[AgentStep] = Field(default_factory=list)
    replanned: bool = False
    client_actions: list[AgentClientAction] = Field(default_factory=list)
    confirmation_request: AgentConfirmationRequest | None = None


class AgentConfigurationUpdate(CamelModel):
    enabled: bool
    api_key: str | None = None
    clear_api_key: bool = False
    max_steps: int = Field(default=6, ge=2, le=10)


class AgentConfigurationResponse(CamelModel):
    enabled: bool
    api_key_configured: bool
    api_key_hint: str | None
    model: str
    max_steps: int
    source: str
    updated_at: str | None


class RuntimeConfiguration(BaseModel):
    enabled: bool
    api_key: str
    model: str
    base_url: str
    max_steps: int
    source: str
