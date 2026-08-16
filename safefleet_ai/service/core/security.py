from __future__ import annotations

import os
import secrets

from fastapi import Header, HTTPException


def require_internal_service(
    x_safefleet_service_token: str | None = Header(
        default=None, alias="X-SafeFleet-Service-Token"
    ),
) -> None:
    expected = os.getenv("AI_INTERNAL_TOKEN", "")
    if not expected:
        raise HTTPException(status_code=503, detail="AI_INTERNAL_TOKEN chưa được cấu hình")
    if not x_safefleet_service_token or not secrets.compare_digest(
        x_safefleet_service_token, expected
    ):
        raise HTTPException(status_code=403, detail="Không có quyền gọi AI service nội bộ")


def require_user_authorization(
    x_user_authorization: str = Header(alias="X-User-Authorization"),
) -> str:
    if not x_user_authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Thiếu token tài xế")
    return x_user_authorization
