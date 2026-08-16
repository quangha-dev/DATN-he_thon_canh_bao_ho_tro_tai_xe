from enum import Enum

from pydantic import BaseModel, Field


class Intent(str, Enum):
    START_TRIP = "START_TRIP"
    PAUSE_TRIP = "PAUSE_TRIP"
    RESUME_TRIP = "RESUME_TRIP"
    COMPLETE_TRIP = "COMPLETE_TRIP"
    GET_DRIVING_TIME = "GET_DRIVING_TIME"
    REPORT_FLOOD = "REPORT_FLOOD"
    SEND_SOS = "SEND_SOS"
    READ_LATEST_WARNING = "READ_LATEST_WARNING"
    UNKNOWN = "UNKNOWN"


class IntentRequest(BaseModel):
    transcript: str = Field(min_length=1, max_length=1000)


class IntentResponse(BaseModel):
    intent: Intent
    confidence: float
    requires_confirmation: bool
    source: str = "LOCAL_RULE"
