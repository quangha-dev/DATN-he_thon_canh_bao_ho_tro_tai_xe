from pydantic import BaseModel, Field


class DocumentOcrFields(BaseModel):
    project_address: str
    voucher_date: str | None = None
    voucher_number: str = ""
    vehicle_plate: str = ""
    driver_name: str = ""
    trip_count: int | None = None
    raw_text: str = ""
    confidences: dict[str, float] = Field(default_factory=dict)


class DocumentOcrResponse(BaseModel):
    engine: str
    elapsed_ms: int
    fields: DocumentOcrFields
