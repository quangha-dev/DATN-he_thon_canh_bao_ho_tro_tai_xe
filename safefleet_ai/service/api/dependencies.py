from functools import lru_cache

from service.agent.configuration import AgentConfigurationStore
from service.agent.orchestrator import AgentOrchestrator
from service.chat.service import DriverChatService
from service.intent.service import IntentClassificationService


@lru_cache
def configuration_store() -> AgentConfigurationStore:
    return AgentConfigurationStore()


@lru_cache
def agent_orchestrator() -> AgentOrchestrator:
    return AgentOrchestrator(configuration_store())


@lru_cache
def intent_service() -> IntentClassificationService:
    return IntentClassificationService(configuration_store())


@lru_cache
def chat_service() -> DriverChatService:
    return DriverChatService(configuration_store())
