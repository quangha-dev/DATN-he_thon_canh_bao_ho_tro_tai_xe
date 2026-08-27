# Deployment Architecture Diagram — SafeFleet

> **Nguồn:** Toàn bộ thông tin được trích xuất trực tiếp từ `docker-compose.yml`, `docker-compose.dev.yml`, và các `Dockerfile`.

---

## Biểu Đồ Triển Khai

```mermaid
graph TB
    %% ══════════════════════════════════════════════════
    %% HOST MACHINE
    %% ══════════════════════════════════════════════════
    subgraph HOST ["🖥️ Host Machine  (Developer / Server)"]
        direction TB

        ENV_FILE["📄 .env file\n(copy từ .env.example)\nchứa secrets & config"]
        DC_CMD["🐳 docker compose\n-f docker-compose.yml\n[-f docker-compose.dev.yml]\n--profile dev"]

        subgraph PORTS_HOST ["🔌 Exposed Ports → Host"]
            P3000["localhost:3000\n→ Frontend (Next.js)"]
            P8080["localhost:8080\n→ Backend (Spring Boot)"]
            P5432["127.0.0.1:${POSTGRES_PORT:-5432}\n→ PostgreSQL"]
            P9000["localhost:9000\n→ MinIO API"]
            P9001["localhost:9001\n→ MinIO Console"]
            P8081["localhost:8081\n→ Adminer [dev only]"]
            P8000_DEV["localhost:8000\n→ AI Service [dev only]"]
        end

        subgraph DOCKER_NETWORK ["🌐 Docker Bridge Network: safefleet"]
            direction TB

            %% ── SERVICE: postgres ──
            subgraph SVC_PG ["postgres  (restart: unless-stopped)"]
                PG_IMG["📦 Image: postgres:17-alpine"]
                PG_ENV["Env:\nPOSTGRES_DB · USER · PASSWORD\nTZ: Asia/Ho_Chi_Minh"]
                PG_VOL["📂 Volume: postgres_data\n→ /var/lib/postgresql/data"]
                PG_HC["❤️ Healthcheck:\npg_isready -U \$USER -d \$DB\ninterval:10s · timeout:5s\nretries:10 · start_period:30s"]
                PG_PORT["Port: 5432 (internal)\n→ host \${POSTGRES_PORT:-5432}"]
            end

            %% ── SERVICE: minio ──
            subgraph SVC_MINIO ["minio  (restart: unless-stopped)"]
                MINIO_IMG["📦 Image: minio/minio\nRELEASE.2025-04-22T22-12-26Z"]
                MINIO_CMD["CMD: server /data\n--console-address :9001"]
                MINIO_ENV["Env:\nMINIO_ROOT_USER\nMINIO_ROOT_PASSWORD"]
                MINIO_VOL["📂 Volume: minio_data → /data"]
                MINIO_HC["❤️ Healthcheck:\nmc ready local\ninterval:10s · retries:10\nstart_period:20s"]
                MINIO_PORTS["Ports:\n9000 (API)\n9001 (Console)"]
            end

            %% ── SERVICE: minio-init ──
            subgraph SVC_INIT ["minio-init  (restart: no)"]
                INIT_IMG["📦 Image: minio/mc\nRELEASE.2025-04-16T18-13-26Z"]
                INIT_SCRIPT["📜 /opt/safefleet/init-bucket.sh\nmc alias set local http://minio:9000\nmc mb --ignore-existing local/\$BUCKET\nmc anonymous set none local/\$BUCKET"]
                INIT_DEP["depends_on:\nminio (service_healthy)"]
            end

            %% ── SERVICE: ai-service ──
            subgraph SVC_AI ["ai-service  (restart: unless-stopped)"]
                AI_BUILD["🔨 Build:\nDockerfile → safefleet_ai/\nBase: python:3.11-slim\nStage: runtime"]
                AI_DEPS["System deps:\ntesseract-ocr · libgomp1 · libgl1\nPyTorch CPU · requirements-ocr.txt"]
                AI_RUN["CMD: uvicorn service.main:app\n--host 0.0.0.0 --port 8000\nUser: safefleet (non-root)"]
                AI_VOL["📂 Volumes:\nai_models → /models\nai_data → /data\nsafefleet_temporal_rules.json\n→ /models/ (read-only)"]
                AI_ENV_SVC["Env:\nAGENT_ENCRYPTION_SECRET\nAI_INTERNAL_TOKEN\nOPENAI_API_KEY · OPENAI_ENABLED=false\nAGENT_MAX_STEPS=6\nBACKEND_INTERNAL_URL=http://backend:8080\nMODEL_DIR=/models\nOCR_MAX_UPLOAD_BYTES=10485760\nTESSERACT_CMD=/usr/bin/tesseract"]
                AI_HC["❤️ Healthcheck:\nurllib.request.urlopen\n(':8000/health', timeout=3)\ninterval:15s · retries:5\nstart_period:20s"]
                AI_EXPOSE["expose: 8000\n(internal only)"]
            end

            %% ── SERVICE: backend ──
            subgraph SVC_BE ["backend  (restart: unless-stopped)"]
                BE_BUILD["🔨 Build:\nmaven:3.9.11-eclipse-temurin-21 AS build\n→ eclipse-temurin:21-jre-jammy AS runtime\nUser: safefleet (non-root)"]
                BE_RUN["ENTRYPOINT:\njava -XX:MaxRAMPercentage=75.0\n-jar /app/app.jar\nSPRING_PROFILES_ACTIVE=docker"]
                BE_ENV_SVC["Env (key vars):\nPOSTGRES_HOST=postgres · PORT=5432\nJWT_SECRET · JWT_EXPIRATION_MINUTES=1440\nCORS_ALLOWED_ORIGINS\nSEED_ENABLED=false\nHANOI_DEMO_DATA_ENABLED=false\nEVIDENCE_STORAGE_PROVIDER=minio\nMINIO_ENDPOINT=http://minio:9000\nSAFETY_EVENT_COOLDOWN_SECONDS=30\nSOS_COOLDOWN_SECONDS=30\nFCM_ENABLED=false\nAI_SERVICE_URL=http://ai-service:8000\nAI_INTERNAL_TOKEN"]
                BE_VOL["📂 Volume:\nevidence_data → /data/evidence"]
                BE_DEP["depends_on:\npostgres (service_healthy)\nminio-init (completed_successfully)\nai-service (service_healthy)"]
                BE_HC["❤️ Healthcheck:\nwget /actuator/health | grep UP\ninterval:15s · timeout:5s\nretries:10 · start_period:60s"]
                BE_PORT["Port: 8080\n→ host \${BACKEND_PORT:-8080}"]
            end

            %% ── SERVICE: frontend ──
            subgraph SVC_FE ["frontend  (restart: unless-stopped)"]
                FE_BUILD["🔨 Build (3-stage):\nnode:22-alpine AS deps → npm ci\nnode:22-alpine AS build → npm run build\nnode:22-alpine AS runtime → standalone\nUser: nextjs (non-root)"]
                FE_RUN["CMD: node server.js\nPORT=3000 · HOSTNAME=0.0.0.0\nNODE_ENV=production\nNEXT_TELEMETRY_DISABLED=1"]
                FE_ARG["Build ARG:\nBACKEND_INTERNAL_URL=http://backend:8080"]
                FE_DEP["depends_on:\nbackend (service_healthy)"]
                FE_HC["❤️ Healthcheck:\nwget -qO- http://127.0.0.1:3000/\ninterval:15s · start_period:45s"]
                FE_PORT["Port: 3000\n→ host \${FRONTEND_PORT:-3000}"]
            end

            %% ── DEV ONLY: adminer ──
            subgraph SVC_ADMINER ["adminer  (profile: dev only)"]
                ADM_IMG["📦 Image: adminer:5"]
                ADM_PORT["Port: 8080 → host:8081"]
                ADM_DEP["depends_on:\npostgres (service_healthy)"]
            end
        end

        %% Docker Volumes
        subgraph VOLUMES ["📂 Docker Named Volumes"]
            V1["postgres_data"]
            V2["minio_data"]
            V3["ai_models"]
            V4["ai_data"]
            V5["evidence_data"]
        end
    end

    %% ══════════════════════════════════════════════════
    %% EXTERNAL SERVICES (Internet)
    %% ══════════════════════════════════════════════════
    subgraph EXTERNAL ["🌍 External Services  (Internet)"]
        EXT_OSRM["OSRM\nrouter.project-osrm.org"]
        EXT_PHOTON["Photon\nphoton.komoot.io"]
        EXT_FCM["Firebase FCM\n(optional)"]
        EXT_OPENAI["OpenAI API\n(optional, disabled)"]
    end

    %% ══════════════════════════════════════════════════
    %% CLIENT DEVICES
    %% ══════════════════════════════════════════════════
    subgraph DEVICES ["📱 Client Devices"]
        MOB["Android Phone\nFlutter App APK"]
        BROWSER["Web Browser\nNext.js Dashboard"]
    end

    %% ══════════════════════════════════════════════════
    %% CONNECTIONS — STARTUP ORDER
    %% ══════════════════════════════════════════════════

    %% Startup dependency chain
    SVC_PG -->|"healthy ✅"| SVC_INIT
    SVC_MINIO -->|"healthy ✅"| SVC_INIT
    SVC_INIT -->|"completed_successfully ✅"| SVC_BE
    SVC_AI -->|"healthy ✅"| SVC_BE
    SVC_PG -->|"healthy ✅"| SVC_BE
    SVC_BE -->|"healthy ✅"| SVC_FE
    SVC_PG -->|"healthy ✅"| SVC_ADMINER

    %% Volume mounts
    V1 --- SVC_PG
    V2 --- SVC_MINIO
    V3 --- SVC_AI
    V4 --- SVC_AI
    V5 --- SVC_BE

    %% Internal communication (Docker network)
    SVC_BE -->|"http://postgres:5432\nJDBC/JPA"| SVC_PG
    SVC_BE -->|"http://minio:9000\nMinIO SDK"| SVC_MINIO
    SVC_BE -->|"http://ai-service:8000\nREST HTTP"| SVC_AI
    SVC_FE -->|"http://backend:8080\nSSR proxy"| SVC_BE
    SVC_AI -->|"http://backend:8080\n(callback)"| SVC_BE

    %% Host port exposure
    SVC_FE --- P3000
    SVC_BE --- P8080
    SVC_PG --- P5432
    SVC_MINIO --- P9000
    SVC_MINIO --- P9001
    SVC_ADMINER --- P8081

    %% Client → Host
    BROWSER -->|"HTTP :3000"| P3000
    MOB -->|"HTTP :8080\nREST + WebSocket"| P8080

    %% Backend → External
    SVC_BE -->|"HTTPS"| EXT_OSRM
    SVC_BE -->|"HTTPS"| EXT_PHOTON
    SVC_BE -.->|"HTTPS (FCM_ENABLED=false)"| EXT_FCM
    SVC_AI -.->|"HTTPS (OPENAI_ENABLED=false)"| EXT_OPENAI

    %% Config
    ENV_FILE --> DC_CMD
    DC_CMD --> DOCKER_NETWORK

    %% Styling
    classDef service fill:#ede9fe,stroke:#7c3aed,color:#3b0764
    classDef store fill:#dbeafe,stroke:#2563eb,color:#1e3a8a
    classDef ext fill:#fef3c7,stroke:#d97706,color:#78350f
    classDef device fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef vol fill:#f1f5f9,stroke:#64748b,color:#334155
    classDef port fill:#fff1f2,stroke:#f43f5e,color:#881337

    class SVC_BE,BE_BUILD,BE_RUN,BE_ENV_SVC,BE_VOL,BE_DEP,BE_HC,BE_PORT service
    class SVC_FE,FE_BUILD,FE_RUN,FE_ARG,FE_DEP,FE_HC,FE_PORT service
    class SVC_AI,AI_BUILD,AI_DEPS,AI_RUN,AI_VOL,AI_ENV_SVC,AI_HC,AI_EXPOSE service
    class SVC_PG,PG_IMG,PG_ENV,PG_VOL,PG_HC,PG_PORT store
    class SVC_MINIO,MINIO_IMG,MINIO_CMD,MINIO_ENV,MINIO_VOL,MINIO_HC,MINIO_PORTS store
    class SVC_INIT,INIT_IMG,INIT_SCRIPT,INIT_DEP service
    class SVC_ADMINER,ADM_IMG,ADM_PORT,ADM_DEP service
    class EXT_OSRM,EXT_PHOTON,EXT_FCM,EXT_OPENAI ext
    class MOB,BROWSER device
    class V1,V2,V3,V4,V5 vol
    class P3000,P8080,P5432,P9000,P9001,P8081,P8000_DEV port
```

---

## Thứ Tự Khởi Động (Startup Order)

```mermaid
sequenceDiagram
    participant PG as postgres
    participant MINIO as minio
    participant INIT as minio-init
    participant AI as ai-service
    participant BE as backend
    participant FE as frontend

    Note over PG: postgres:17-alpine starts
    PG->>PG: pg_isready healthcheck
    Note over PG: ✅ healthy (≤30s start_period)

    Note over MINIO: minio starts
    MINIO->>MINIO: mc ready local
    Note over MINIO: ✅ healthy (≤20s start_period)

    MINIO-->>INIT: service_healthy → trigger
    Note over INIT: minio-init runs init-bucket.sh
    INIT->>MINIO: mc mb local/safefleet-evidence
    INIT->>MINIO: mc anonymous set none
    Note over INIT: ✅ completed_successfully

    Note over AI: ai-service starts
    AI->>AI: uvicorn service.main:app :8000
    AI->>AI: urllib GET /health healthcheck
    Note over AI: ✅ healthy (≤20s start_period)

    PG-->>BE: service_healthy ✅
    INIT-->>BE: completed_successfully ✅
    AI-->>BE: service_healthy ✅
    Note over BE: backend starts
    BE->>PG: Flyway V1-V13 migration
    BE->>BE: /actuator/health probe
    Note over BE: ✅ healthy (≤60s start_period)

    BE-->>FE: service_healthy ✅
    Note over FE: frontend starts
    FE->>FE: node server.js :3000
    Note over FE: ✅ healthy (≤45s start_period)
```

---

## Docker Build — Từng Service

| Service | Base Image | Build Stages | User | Port |
|---|---|---|---|---|
| **backend** | `maven:3.9.11-eclipse-temurin-21` → `eclipse-temurin:21-jre-jammy` | 2 stages: build + runtime | `safefleet` (non-root) | 8080 |
| **frontend** | `node:22-alpine` | 3 stages: deps + build + runtime | `nextjs` (uid:1001) | 3000 |
| **ai-service** | `python:3.11-slim` | 3 stages: base + test + runtime | `safefleet` (non-root) | 8000 |
| **postgres** | `postgres:17-alpine` | Official image | `postgres` | 5432 |
| **minio** | `minio/minio:RELEASE.2025-04-22T22-12-26Z` | Official image | `minio` | 9000/9001 |
| **minio-init** | `minio/mc:RELEASE.2025-04-16T18-13-26Z` | Official image, run once | — | — |

---

## So Sánh: Production vs Dev Profile

| Cấu hình | Production (`docker-compose.yml`) | Dev (`docker-compose.dev.yml`) |
|---|---|---|
| AI Service port | Internal only (`expose: 8000`) | Exposed to host `:8000` |
| Seed data | `SEED_ENABLED=false` | `SEED_ENABLED=true` |
| Hà Nội demo data | `HANOI_DEMO_DATA_ENABLED=false` | `HANOI_DEMO_DATA_ENABLED=true` |
| Log level | `INFO` | `DEBUG` |
| Adminer UI | ❌ Không có | ✅ `adminer:5` tại `:8081` |

---

## Bảng Nguồn Source Code

| Thành phần | File nguồn | Dòng / Chi tiết |
|---|---|---|
| Backend base image | `web_quan_ly/backend/Dockerfile:2,9` | `maven:3.9.11-eclipse-temurin-21` → `eclipse-temurin:21-jre-jammy` |
| Backend JVM flag | `Dockerfile:24` | `-XX:MaxRAMPercentage=75.0` |
| Backend healthcheck | `Dockerfile:22-23` | `curl /actuator/health`, interval:15s, start_period:45s |
| Backend non-root user | `Dockerfile:13-14,19` | `useradd safefleet`, `USER safefleet` |
| Frontend base image | `web_quan_ly/frontend/Dockerfile:2,7,16` | `node:22-alpine` 3 stages |
| Frontend internal URL | `Dockerfile:10-11` | `ARG BACKEND_INTERNAL_URL=http://backend:8080` |
| Frontend healthcheck | `Dockerfile:28-29` | `wget -qO- http://127.0.0.1:3000/`, start_period:30s |
| AI base image | `safefleet_ai/Dockerfile:2` | `python:3.11-slim` |
| AI system deps | `Dockerfile:7` | `tesseract-ocr libgomp1` (base) + `libgl1` (runtime) |
| AI PyTorch CPU | `Dockerfile:11` | `--index-url https://download.pytorch.org/whl/cpu` |
| AI healthcheck | `Dockerfile:34-35` | `urllib.request.urlopen('/health', timeout=3)` |
| AI test stage | `Dockerfile:14-21` | `--target test`, runs `pytest -q` |
| MinIO image | `docker-compose.yml:134` | `minio/minio:RELEASE.2025-04-22T22-12-26Z` |
| MinIO init anonymous | `docker/minio/init-bucket.sh:10` | `mc anonymous set none` (bucket private) |
| Startup order | `docker-compose.yml:65-70` | `depends_on` với conditions |
| Backend start_period | `docker-compose.yml:76` | 60s (chờ Flyway migration) |
| Docker network | `docker-compose.yml:175-177` | `driver: bridge`, name: `safefleet` |
| Dev: Adminer | `docker-compose.dev.yml:14-23` | `adminer:5`, port 8081, profile: dev |
| Health check script | `docker/scripts/health-check.sh` | Kiểm tra 4 endpoints: backend, frontend, ai-service, minio |
