from __future__ import annotations

import logging

from service.agent.configuration import AgentConfigurationStore
from service.chat.models import ChatMessage, ChatResponse
from service.providers.openai import OpenAiClient, OpenAiError

LOGGER = logging.getLogger("safefleet.ai.chat")


class DriverChatService:
    def __init__(self, configuration_store: AgentConfigurationStore, openai: OpenAiClient | None = None):
        self._configuration_store = configuration_store
        self._openai = openai or OpenAiClient()

    def respond(self, messages: list[ChatMessage]) -> ChatResponse:
        configuration = self._configuration_store.runtime()
        if configuration.enabled and configuration.api_key:
            try:
                text = self._openai.response_text(
                    configuration,
                    instructions=(
                        "Bạn là trợ lý giọng nói SafeFleet dành cho tài xế Việt Nam. Trả lời ngắn, rõ, "
                        "ưu tiên an toàn và không khuyến khích thao tác màn hình khi xe chạy. Không tuyên bố "
                        "đã gửi SOS, báo ngập hay thay đổi chuyến; hành động phải dùng luồng xác nhận riêng."
                    ),
                    input_value=[message.model_dump() for message in messages],
                    max_output_tokens=500,
                )
                return ChatResponse(response_text=text, model=configuration.model, source="OPENAI")
            except OpenAiError as exception:
                LOGGER.warning("OpenAI chat failed (%s)", type(exception).__name__)

        latest = messages[-1].content.lower()
        if any(word in latest for word in ("sos", "khẩn cấp", "cứu hộ")):
            text = "Tình huống có vẻ khẩn cấp. Hãy dùng lệnh SOS và xác nhận để gửi vị trí đến điều phối."
        elif "ngập" in latest:
            text = "Bạn có thể mở Bản đồ để tìm tuyến né ngập hoặc dùng lệnh báo ngập có xác nhận."
        else:
            text = "Tôi đang ở chế độ ngoại tuyến. Tôi vẫn có thể hỗ trợ lệnh SOS, báo ngập, dẫn đường và đọc cảnh báo."
        return ChatResponse(response_text=text, model="local-safe-fallback", source="LOCAL_FALLBACK")
