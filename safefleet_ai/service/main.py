from fastapi import FastAPI

from service.api.routers import agent, chat, health, intent, mcp, models, ocr


def create_app() -> FastAPI:
    application = FastAPI(
        title="SafeFleet AI Service",
        version="0.2.0",
        description=(
            "Production AI boundary for SafeFleet: OCR, intent classification, "
            "OpenAI configuration and the server-side data agent."
        ),
    )
    application.include_router(health.router)
    application.include_router(models.router)
    application.include_router(intent.router)
    application.include_router(chat.router)
    application.include_router(ocr.router)
    application.include_router(agent.router)
    application.include_router(mcp.router)
    return application


app = create_app()
