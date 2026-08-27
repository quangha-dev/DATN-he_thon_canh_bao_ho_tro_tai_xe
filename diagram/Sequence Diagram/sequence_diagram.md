# Sequence Diagram — SafeFleet

> **Nguồn:** Toàn bộ thứ tự gọi hàm, HTTP endpoint, header và dữ liệu trao đổi được trích xuất từ source code thực tế.

---

## 1. Sequence: Đăng Nhập & Khởi Tạo App (Login & Bootstrap)

> Nguồn: `AuthController.java`, `JwtService.java`, `MobileAppService.java:bootstrap()`

```mermaid
sequenceDiagram
    actor Driver as 📱 Tài xế (Flutter)
    participant API as ⚙️ Backend :8080
    participant JWT as JwtService
    participant DB as 🐘 PostgreSQL
    participant WS as 🔌 WebSocket

    Driver->>API: POST /api/v1/auth/login\n{username, password}
    API->>DB: SELECT users WHERE username=?
    DB-->>API: UserAccount + Role
    API->>JWT: generateAccessToken(user)\ngenerateRefreshToken(user)
    JWT-->>API: accessToken (exp: 1440min)\nrefreshToken (exp: 30days)
    API-->>Driver: 200 {accessToken, refreshToken, user}

    Note over Driver: Lưu token vào FlutterSecureStorage

    Driver->>API: GET /api/v1/mobile/bootstrap\nAuthorization: Bearer <JWT>
    API->>JWT: validateToken()
    JWT-->>API: valid userId, role=DRIVER
    API->>DB: SELECT driver WHERE user_id=?
    DB-->>API: Driver + currentVehicle + currentTrip
    API->>DB: SELECT notifications (page 0, size 20)
    DB-->>API: 20 notifications mới nhất
    API-->>Driver: 200 MobileBootstrapResponse\n{driver, assignment, notifications}

    Driver->>WS: CONNECT /ws-native\nSTOMP CONNECT\nAuthorization: Bearer <JWT>
    WS-->>Driver: CONNECTED
    Driver->>WS: SUBSCRIBE /queue/notifications
    Driver->>WS: SUBSCRIBE /topic/trips
```

---

## 2. Sequence: Bắt Đầu Chuyến Đi (Trip Start)

> Nguồn: `MobileController.java`, `MobileAppService.java:startWorkflow()`, `NotificationService.java`

```mermaid
sequenceDiagram
    actor Driver as 📱 Tài xế
    participant API as ⚙️ Backend :8080
    participant MAS as MobileAppService
    participant TS as TripService
    participant DTS as DrivingTimeService
    participant NS as NotificationService
    participant DB as 🐘 PostgreSQL
    participant WS as 🔌 WebSocket /topic/notifications
    participant WEB as 🖥️ Dashboard (Next.js)

    Driver->>API: POST /api/v1/mobile/trips/{id}/workflow/start\nAuthorization: Bearer <JWT>\n{note, clientEventId}

    API->>MAS: startWorkflow(tripId, request)
    MAS->>DB: SELECT mobile_command_receipts\nWHERE client_event_id=?
    alt clientEventId đã tồn tại (idempotency)
        DB-->>MAS: existing receipt
        MAS-->>API: replay response
        API-->>Driver: 200 (cached)
    end

    MAS->>DB: SELECT trips WHERE id=?
    DB-->>MAS: Trip {vehicle=?, driver=?}

    alt vehicle == null
        MAS-->>API: BadRequestException "Chưa gán xe"
        API-->>Driver: 400 Error
    end

    MAS->>DB: SELECT pre_trip_checklists\nWHERE trip_id=? AND driver_id=?
    alt checklist chưa nộp
        MAS-->>API: BadRequestException "Phải hoàn thành checklist"
        API-->>Driver: 400 Error
    end

    MAS->>TS: start(tripId, actionRequest)
    TS->>DB: UPDATE trips SET status='IN_PROGRESS'\nactual_start_time=now()
    TS->>DB: INSERT trip_timelines (STARTED)

    MAS->>DTS: startSession(driver, vehicle, trip)
    DTS->>DB: INSERT driving_sessions\n{status=ACTIVE, started_at=now()}

    MAS->>DB: UPDATE drivers SET status='DRIVING'\nUPDATE vehicles SET status='RUNNING'

    MAS->>NS: broadcast(FLEET_MANAGER, DISPATCHER,\nSAFETY_OFFICER, "Chuyến X đã bắt đầu")
    NS->>DB: INSERT notifications (bulk)
    NS->>WS: convertAndSend("/topic/notifications", payload)
    WS-->>WEB: 🔔 Push notification realtime

    MAS->>DB: INSERT mobile_command_receipts\n{clientEventId, response_json}

    API-->>Driver: 200 MobileWorkflowResponse\n{trip, drivingSession}
```

---

## 3. Sequence: Phát Hiện & Gửi Cảnh Báo Buồn Ngủ (Drowsiness Alert)

> Nguồn: `stgt_drowsiness_engine.dart`, `MobileController.java`, `SafetyEventService.java`

```mermaid
sequenceDiagram
    actor Driver as 👁️ Camera / Driver
    participant CAM as 📷 Flutter Camera
    participant MLKIT as 🔍 ML Kit Face Mesh
    participant TFLITE as 🧠 TFLite STGT Model
    participant APP as 📱 Flutter App
    participant API as ⚙️ Backend :8080
    participant SES as SafetyEventService
    participant NS as NotificationService
    participant DB as 🐘 PostgreSQL
    participant WS as 🔌 WebSocket

    CAM->>MLKIT: frame stream (30fps)
    MLKIT->>MLKIT: FaceMeshDetector\n468 face landmarks
    MLKIT-->>APP: landmarks: leftEyeOpen, rightEyeOpen\nheadPitch, headYaw, headRoll\nmouthOpenRatio, irisMovement

    APP->>TFLITE: Sliding window 75 frames × 6 features\n(windowSize=75, samplePeriod=40ms)
    TFLITE->>TFLITE: Inference: stgt-fold-1\ndrowsiness_model.tflite
    TFLITE-->>APP: score: 1.0..10.0

    alt score >= dangerScore (6) AND cooldown (20s) passed
        APP->>APP: 🔔 Cảnh báo âm thanh + rung
        APP->>API: POST /api/v1/mobile/safety-events\nAuthorization: Bearer <JWT>\n{eventType=DROWSINESS, severity=HIGH\nconfidence, lat, lng, speed, clientEventId}

        API->>SES: create(request)
        SES->>DB: SELECT safety_events WHERE\nclient_event_id=? (idempotency)
        alt không trùng lặp
            SES->>DB: SELECT safety_events WHERE\ndriver_id=? AND created_at > now()-30s
            alt không có trong cooldown (30s)
                SES->>DB: INSERT safety_events\n{status=NEW, receivedAt=now()}
                SES->>SES: applySafetyScoreImpact()\nHIGH: safetyScore -= 10
                SES->>DB: UPDATE drivers SET safety_score=?
                alt safetyScore < 50
                    SES->>DB: UPDATE drivers SET status='SUSPENDED'
                    SES->>NS: notify SAFETY_OFFICER\n"Tài xế có nguy cơ cao"
                end
                SES->>NS: createGlobal(AI_ALERT,\n"Cảnh báo buồn ngủ", ...)
                NS->>DB: INSERT notifications
                NS->>WS: convertAndSend\n("/topic/notifications", payload)
                WS-->>API: 🔔 Broadcast đến SAFETY_OFFICER
            end
        end
        API-->>APP: 201 SafetyEventResponse
    end
```

---

## 4. Sequence: Gửi SOS & Xử Lý Cứu Hộ

> Nguồn: `IncidentService.java:sos()`, `NotificationService.java`, `PushNotificationService.java`

```mermaid
sequenceDiagram
    actor Driver as 📱 Tài xế
    actor Dispatcher as 🖥️ Dispatcher
    actor Rescue as 🚑 Rescue Team
    participant API as ⚙️ Backend :8080
    participant IS as IncidentService
    participant NS as NotificationService
    participant PUSH as PushNotificationService
    participant DB as 🐘 PostgreSQL
    participant WS as 🔌 WebSocket
    participant FCM as 🔔 Firebase FCM

    Driver->>API: POST /api/v1/mobile/incidents/sos\nAuthorization: Bearer <JWT>\n{lat, lng, severity=CRITICAL\ndescription, clientEventId}

    API->>IS: sos(request)
    IS->>DB: SELECT incidents WHERE client_event_id=?
    alt idempotency hit
        DB-->>IS: existing incident
        IS-->>API: 200 existing
    end

    IS->>DB: SELECT incidents WHERE driver_id=?\nAND created_at > now()-30s (cooldown)
    alt trong cooldown 30s
        IS-->>API: 200 recent incident (deduplicated)
    end

    IS->>DB: INSERT incidents\n{incidentCode=INC-xxxx\ntype=SOS, severity=CRITICAL\nstatus=OPEN, receivedAt=now()}

    IS->>DB: INSERT incident_timelines\n{action=SOS_CREATED\n"SOS submitted from driver app"}

    IS->>NS: createGlobal(SOS, "SOS mới", description,\nroles=[DISPATCHER, RESCUE_TEAM, SAFETY_OFFICER])
    NS->>DB: INSERT notifications (bulk)
    NS->>WS: convertAndSend("/topic/notifications")
    WS-->>Dispatcher: 🔴 SOS Alert realtime

    NS->>PUSH: enqueuePush(notificationId, userIds)
    PUSH->>DB: INSERT pending_push_notifications\n{status=PENDING, next_attempt_at=now()}

    Note over PUSH: Scheduler dispatch interval: 30s
    PUSH->>DB: SELECT pending_push_notifications\nWHERE status=PENDING
    PUSH->>FCM: POST FCM API (nếu FCM_ENABLED=true)
    FCM-->>Rescue: 📲 Push notification

    API-->>Driver: 201 IncidentResponse\n{id, incidentCode, status=OPEN}

    Dispatcher->>API: PUT /api/v1/incidents/{id}/accept\nAuthorization: Bearer <JWT>
    API->>IS: accept(id)
    IS->>DB: UPDATE incidents SET status=ACCEPTED
    IS->>DB: INSERT incident_timelines (ACCEPTED)
    API-->>Dispatcher: 200 IncidentResponse {status=ACCEPTED}

    Dispatcher->>API: PUT /api/v1/incidents/{id}/assign\n{assignedUserId: rescueTeamId}
    API->>IS: assign(id, userId)
    IS->>DB: UPDATE incidents SET assigned_to=?
    IS->>NS: notify rescueUser "Bạn được giao xử lý SOS"
    API-->>Dispatcher: 200 IncidentResponse

    Rescue->>API: POST /api/v1/incidents/{id}/timeline\n{action=ARRIVED, note}
    API->>IS: addTimeline(id, request)
    IS->>DB: INSERT incident_timelines (ARRIVED)
    API-->>Rescue: 200 IncidentTimelineResponse

    Rescue->>API: PUT /api/v1/incidents/{id}/close\n{note="Đã xử lý"}
    API->>IS: close(id)
    IS->>DB: UPDATE incidents SET status=RESOLVED
    IS->>DB: INSERT incident_timelines (RESOLVED)
    API-->>Rescue: 200 IncidentResponse {status=RESOLVED}
```

---

## 5. Sequence: Navigation — Tìm Tuyến Đường Tránh Ngập

> Nguồn: `NavigationService.java`, `OsrmRoutingProvider.java`, `FloodReportService.java:routeRisk()`

```mermaid
sequenceDiagram
    actor Driver as 📱 Tài xế
    participant API as ⚙️ Backend :8080
    participant NS as NavigationService
    participant FRS as FloodReportService
    participant OSRM as 🗺️ OSRM\nrouter.project-osrm.org
    participant DB as 🐘 PostgreSQL

    Driver->>API: POST /api/v1/mobile/navigation/start\nAuthorization: Bearer <JWT>\n{originLat, originLng\ndestLat, destLng, tripId}

    API->>NS: startSession(request, driver)
    NS->>DB: INSERT navigation_sessions\n{status=ACTIVE, session_uuid=UUID}

    NS->>OSRM: GET /route/v1/driving/{orig};{dest}\n?alternatives=3&geometries=geojson\nUser-Agent: SafeFleet-DATN/1.0
    OSRM-->>NS: [{routes}] × 3 alternatives

    NS->>FRS: routeRisk(routeCoords)
    FRS->>DB: SELECT flood_reports WHERE\nstatus IN (UNVERIFIED, VERIFIED)
    DB-->>FRS: active flood reports
    FRS->>FRS: Tính giao nhau giữa route và flood zones\n→ floodIntersectionCount, riskScore

    loop 3 route candidates
        NS->>DB: INSERT navigation_route_candidates\n{routeIndex, distanceMeters\ndurationSeconds, riskScore\nfloodIntersectionCount, geometryJson\nis_recommended=true (riskScore thấp nhất)}
    end

    API-->>Driver: 200 NavigationSessionResponse\n{sessionId, candidates[3]\nrecommendedCandidateId}

    Driver->>API: PUT /api/v1/mobile/navigation/{sessionId}/select\n{candidateId}
    API->>DB: UPDATE navigation_sessions\nSET selected_candidate_id=?
    API-->>Driver: 200 selected route

    loop Trong khi điều hướng
        Driver->>API: POST /api/v1/mobile/navigation/{sessionId}/events\n{eventType=OFF_ROUTE, lat, lng\ndistanceToRouteMeters}
        API->>DB: INSERT navigation_events\n{eventType, lat, lng\noccurredAt=now()}
        API-->>Driver: 200 NavigationEventResponse
    end

    Driver->>API: POST /api/v1/mobile/navigation/{sessionId}/end
    API->>DB: UPDATE navigation_sessions\nSET status=COMPLETED, ended_at=now()
    API-->>Driver: 200
```

---

## 6. Sequence: AI Voice Agent — Truy Vấn Dữ Liệu

> Nguồn: `MobileAppService.java:submitAgentCommand()`, `SafeFleetAiGateway.java`, `AgentOrchestrator.py`, `tools.py`

```mermaid
sequenceDiagram
    actor Driver as 📱 Tài xế (giọng nói)
    participant APP as Flutter App
    participant API as ⚙️ Backend :8080
    participant MAS as MobileAppService
    participant GW as SafeFleetAiGateway
    participant AIAPI as 🤖 AI Service :8000
    participant RULES as Intent Rules Engine
    participant GPT as ☁️ OpenAI gpt-4o-mini
    participant DB as 🐘 PostgreSQL

    Driver->>APP: 🎤 Nói "tôi còn bao nhiêu giờ lái?"
    APP->>APP: speech_to_text → transcript text
    APP->>API: POST /api/v1/mobile/agent/commands\nAuthorization: Bearer <JWT>\n{transcript, commandType=VOICE}

    API->>MAS: submitAgentCommand(request)
    MAS->>MAS: rateLimiter.check(userId, "AGENT"\n10 req/min)
    MAS->>MAS: activeTripFor(driver)

    MAS->>GW: classify(transcript)
    GW->>AIAPI: POST /intent/classify\nX-SafeFleet-Service-Token: <token>\n{transcript: "tôi còn bao nhiêu giờ lái?"}

    AIAPI->>RULES: classify_locally(transcript)
    RULES->>RULES: normalize → check 8 rules\n"còn lái" → GET_DRIVING_TIME
    RULES-->>AIAPI: Intent=GET_DRIVING_TIME\nconfidence=0.95\nrequires_confirmation=false\nsource=LOCAL_RULE

    AIAPI-->>GW: 200 IntentResponse
    GW-->>MAS: Classification{GET_DRIVING_TIME, 0.95, false}

    MAS->>DB: INSERT agent_commands\n{interpretedIntent=GET_DRIVING_TIME\nstatus=RECEIVED\nclassificationSource=LOCAL_RULE}

    MAS->>MAS: applyAgentClassification()
    Note over MAS: GET_DRIVING_TIME: no confirmation → execute directly
    MAS->>DB: SELECT driving_sessions WHERE driver_id=?\nAND status=ACTIVE
    DB-->>MAS: DrivingSession {continuousMinutes}
    MAS->>DB: UPDATE agent_commands SET status=EXECUTED
    MAS->>DB: SELECT system_settings\n(MAX_CONTINUOUS_DRIVING_MINUTES)
    MAS-->>API: MobileAgentCommandResponse\n{intent, responseText="Bạn đã lái 2.5 giờ..."\nstatus=EXECUTED}

    API-->>APP: 200 response
    APP->>APP: flutter_tts.speak(responseText)
    APP-->>Driver: 🔊 "Bạn đã lái 2.5 giờ liên tục..."

    Note over Driver,GPT: ─── Luồng khi cần OpenAI (Data Agent) ───

    Driver->>APP: 🎤 "Cho tôi xem chuyến tháng này"
    APP->>API: POST /api/v1/mobile/agent/commands\n{transcript: "chuyến tháng này"}

    API->>MAS: submitAgentCommand()
    MAS->>GW: classify() → UNKNOWN (no local rule match)
    GW->>AIAPI: POST /intent/classify {transcript}
    AIAPI->>RULES: classify_locally() → UNKNOWN
    AIAPI->>GPT: structured_response()\nmax_output_tokens=200
    GPT-->>AIAPI: {intent: UNKNOWN, confidence: 0.1}
    AIAPI-->>GW: UNKNOWN

    MAS->>DB: INSERT agent_commands {intent=UNKNOWN}
    Note over MAS: UNKNOWN → delegate to Data Agent (chat endpoint)

    APP->>API: POST /api/v1/mobile/agent/chat\n{messages: [{role:user, content}]}
    API->>GW: respond(request, userAuthorization)
    GW->>AIAPI: POST /agent/respond\nX-SafeFleet-Service-Token: <token>\nX-User-Authorization: Bearer <JWT>\n{messages}

    AIAPI->>AIAPI: Pre-flight checks\n(other driver? weather?)
    AIAPI->>GPT: _create_plan() → Plan
    GPT-->>AIAPI: {goal, steps[], expected_tools[]}

    loop max_steps = 6
        AIAPI->>GPT: chat(messages, tools, tool_choice=auto)
        GPT-->>AIAPI: tool_calls: [{name: get_monthly_report\nyear: 2026, month: 8}]
        AIAPI->>AIAPI: mcp_client.execute("get_monthly_report"\n{year:2026, month:8})
        AIAPI->>API: GET /api/v1/mobile/activity/monthly?month=2026-08\nAuthorization: Bearer <JWT> (timeout 15s)
        API->>DB: SELECT trips, safety_events, driving_sessions...
        DB-->>API: monthly activity data
        API-->>AIAPI: 200 {data: monthlyReport}
        AIAPI->>GPT: append tool result to messages
        GPT-->>AIAPI: text answer (no more tool_calls)
    end

    AIAPI-->>GW: AgentChatResponse\n{responseText, status=COMPLETED}
    GW-->>API: MobileAgentChatResponse
    API-->>APP: 200 {responseText}
    APP->>APP: flutter_tts.speak()
    APP-->>Driver: 🔊 Tổng hợp báo cáo tháng
```

---

## Bảng Nguồn Source Code

| Sequence | File nguồn | Chi tiết kỹ thuật |
|---|---|---|
| Login JWT | `auth/service/AuthService.java` | accessToken exp: 1440min, refreshToken: 30days |
| Bootstrap | `mobile/service/MobileAppService.java:140` | notification page 0 size 20 |
| WebSocket connect | `config/WebSocketConfig.java:53` | `/ws-native`, STOMP, `/queue` + `/topic` |
| Trip start idempotency | `MobileAppService.java:462-464` | `mobile_command_receipts` lookup bằng clientEventId |
| Checklist gate | `MobileAppService.java:468-472` | `checklistPassed()` bắt buộc |
| DrivingSession start | `DrivingTimeService.java` | `status=ACTIVE, startedAt=now()` |
| Notification broadcast | `NotificationService.java:48,74` | `messagingTemplate.convertAndSend("/topic/notifications")` |
| Safety cooldown | `SafetyEventService.java:76` | `now().minusSeconds(cooldownSeconds)` |
| Safety score penalty | `SafetyEventService.java:244-256` | HIGH:-10, CRITICAL:-20, suspend <50 |
| SOS cooldown | `IncidentService.java:63,138` | `@Value("${app.sos.cooldown-seconds:30}")` |
| SOS idempotency | `IncidentService.java:123-126` | clientEventId deduplication |
| OSRM call | `OsrmRoutingProvider.java` | User-Agent: SafeFleet-DATN/1.0, alternatives=3 |
| Flood route risk | `FloodReportService.java:166` | Giao nhau route với active flood reports |
| AI Gateway classify | `SafeFleetAiGateway.java:70-79` | `POST /intent/classify`, RestClient |
| AI Gateway respond | `SafeFleetAiGateway.java:47-57` | `POST /agent/respond`, X-User-Authorization |
| Rate limiter | `MobileAppService.java:857` | AGENT: 10 req/min |
| Agent direct exec | `MobileAppService.java:880` | `applyAgentClassification()` cho GET_DRIVING_TIME |
| Agent confirm | `MobileAppService.java:885-961` | switch(intent) → gọi workflow/sos/flood |
| MCP tool executor | `agent/tools.py:11-17` | 5 ALLOWED_TOOLS, HTTP GET timeout 15s |
| Agent max steps | `agent/orchestrator.py:105` | `while step_index < max_steps` |
| TTS response | `safe_fleet_driver_ui/lib/core/` | `flutter_tts.speak(responseText)` |
