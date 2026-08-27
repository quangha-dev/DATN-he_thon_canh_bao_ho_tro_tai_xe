# syntax=docker/dockerfile:1.7
FROM python:3.11-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends tesseract-ocr libgomp1 \
    && rm -rf /var/lib/apt/lists/*
COPY safefleet_ai/requirements.txt safefleet_ai/requirements-ocr.txt safefleet_ai/requirements-torch-cpu.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --index-url https://download.pytorch.org/whl/cpu -r requirements-torch-cpu.txt \
    && pip install -r requirements-ocr.txt

FROM base AS test
COPY safefleet_ai/requirements-dev.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip install --no-cache-dir -r requirements-dev.txt
COPY safefleet_ai/service ./service
COPY safefleet_ai/tests ./tests
COPY safefleet_ai/training ./training
COPY safefleet_ai/evaluation ./evaluation
COPY safefleet_ai/knowledge ./knowledge
COPY safefleet_ai/models/safefleet_temporal_rules.json ./models/safefleet_temporal_rules.json
CMD ["python", "-m", "pytest", "-q"]

FROM base AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system safefleet \
    && useradd --system --gid safefleet --home-dir /app safefleet
COPY safefleet_ai/service ./service
COPY safefleet_ai/knowledge ./knowledge
COPY safefleet_ai/models/ocr /app/ocr_models
RUN mkdir -p /models /data && chown -R safefleet:safefleet /app /models /data
USER safefleet
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"
CMD ["uvicorn", "service.main:app", "--host", "0.0.0.0", "--port", "8000"]
