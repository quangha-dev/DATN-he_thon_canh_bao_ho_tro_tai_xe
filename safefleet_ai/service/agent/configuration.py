from __future__ import annotations

import base64
import hashlib
import json
import os
import secrets
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from service.agent.models import (
    AgentConfigurationResponse,
    AgentConfigurationUpdate,
    RuntimeConfiguration,
)

MODEL = "gpt-4o-mini"
DEFAULT_BASE_URL = "https://api.openai.com/v1"
_PREFIX = "gcm:v1:"


class ConfigurationError(ValueError):
    pass


class AgentConfigurationStore:
    def __init__(self, path: str | None = None, encryption_secret: str | None = None):
        self._path = Path(path or os.getenv("AI_CONFIG_PATH", "/data/agent_config.json"))
        secret = encryption_secret or os.getenv("AGENT_ENCRYPTION_SECRET", "")
        if len(secret) < 32:
            raise RuntimeError("AGENT_ENCRYPTION_SECRET phải có ít nhất 32 ký tự")
        self._key = hashlib.sha256(secret.encode("utf-8")).digest()
        self._lock = threading.RLock()

    def public(self) -> AgentConfigurationResponse:
        stored = self._read()
        runtime = self.runtime(stored)
        configured = bool(runtime.api_key)
        return AgentConfigurationResponse(
            enabled=runtime.enabled,
            api_key_configured=configured,
            api_key_hint=f"••••{runtime.api_key[-4:]}" if configured else None,
            model=MODEL,
            max_steps=runtime.max_steps,
            source=runtime.source,
            updated_at=stored.get("updated_at"),
        )

    def update(self, request: AgentConfigurationUpdate) -> AgentConfigurationResponse:
        with self._lock:
            stored = self._read_unlocked()
            incoming_key = (request.api_key or "").strip()
            if request.clear_api_key:
                stored["encrypted_api_key"] = None
            elif incoming_key:
                if not incoming_key.startswith("sk-") or len(incoming_key) < 20:
                    raise ConfigurationError("OpenAI API key không đúng định dạng")
                stored["encrypted_api_key"] = self._encrypt(incoming_key)
            stored.update(
                enabled=request.enabled,
                model=MODEL,
                base_url=DEFAULT_BASE_URL,
                max_steps=max(2, min(10, request.max_steps)),
                updated_at=datetime.now(timezone.utc).isoformat(),
            )
            runtime = self.runtime(stored)
            if request.enabled and not runtime.api_key:
                raise ConfigurationError("Cần nhập OpenAI API key trước khi bật agent")
            self._write_unlocked(stored)
        return self.public()

    def runtime(self, stored: dict[str, Any] | None = None) -> RuntimeConfiguration:
        stored = stored or self._read()
        environment_key = os.getenv("OPENAI_API_KEY", "").strip()
        environment_enabled = os.getenv("OPENAI_ENABLED", "false").strip().lower() == "true"
        if environment_key:
            api_key = environment_key
            enabled = environment_enabled
            source = "ENVIRONMENT"
            max_steps = int(os.getenv("AGENT_MAX_STEPS", str(stored.get("max_steps", 6))))
        else:
            encrypted = stored.get("encrypted_api_key")
            api_key = self._decrypt(encrypted) if encrypted else ""
            enabled = bool(stored.get("enabled"))
            source = "DATABASE"
            max_steps = int(stored.get("max_steps", 6))
        return RuntimeConfiguration(
            enabled=enabled,
            api_key=api_key,
            model=MODEL,
            base_url=DEFAULT_BASE_URL,
            max_steps=max(2, min(10, max_steps)),
            source=source,
        )

    def _read(self) -> dict[str, Any]:
        with self._lock:
            return self._read_unlocked()

    def _read_unlocked(self) -> dict[str, Any]:
        if not self._path.is_file():
            return self._defaults()
        try:
            loaded = json.loads(self._path.read_text(encoding="utf-8"))
            return {**self._defaults(), **loaded}
        except (OSError, json.JSONDecodeError, TypeError) as exception:
            raise ConfigurationError("Không đọc được cấu hình agent") from exception

    def _write_unlocked(self, value: dict[str, Any]) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self._path.with_suffix(".tmp")
        temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(temporary, self._path)

    def _encrypt(self, plain_text: str) -> str:
        nonce = secrets.token_bytes(12)
        packed = nonce + AESGCM(self._key).encrypt(nonce, plain_text.encode("utf-8"), None)
        return _PREFIX + base64.b64encode(packed).decode("ascii")

    def _decrypt(self, encrypted_text: str) -> str:
        try:
            if not encrypted_text.startswith(_PREFIX):
                raise ValueError("Unsupported encrypted value")
            packed = base64.b64decode(encrypted_text[len(_PREFIX) :])
            return AESGCM(self._key).decrypt(packed[:12], packed[12:], None).decode("utf-8")
        except Exception as exception:
            raise ConfigurationError("Không giải mã được cấu hình agent") from exception

    @staticmethod
    def _defaults() -> dict[str, Any]:
        return {
            "enabled": False,
            "encrypted_api_key": None,
            "model": MODEL,
            "base_url": DEFAULT_BASE_URL,
            "max_steps": 6,
            "updated_at": None,
        }
