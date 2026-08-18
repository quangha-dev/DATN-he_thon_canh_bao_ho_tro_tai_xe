# Activity Diagram — SafeFleet

> **Nguồn:** Toàn bộ luồng nghiệp vụ được trích xuất trực tiếp từ source code backend Java.
> File tham chiếu chính: `MobileAppService.java`, `SafetyEventService.java`, `IncidentService.java`, `FloodReportService.java`

---

## 1. Activity: Bắt Đầu Chuyến Đi (Trip Start Workflow)

> Nguồn: `MobileAppService.java:startWorkflow()`, `TripService.java:start()`

```mermaid
flowchart TD
    START(["🟢 Tài xế nhấn Bắt đầu chuyến"])

    IDEMPOTENT{"clientEventId\nđã tồn tại?"}
    REPLAY["↩️ Trả về kết quả cũ\n(Idempotency replay)"]

    VEHICLE{"Chuyến đã\ngán xe?"}
    NO_VEHICLE["❌ BadRequestException\n'Chuyến chưa được gán xe'"]

    CHECKLIST_EXIST{"Checklist đã\nnộp chưa?"}
    NO_CHECKLIST["❌ BadRequestException\n'Phải hoàn thành checklist\ntrước khi bắt đầu'"]

    CHECKLIST_PASS{"Checklist\ncó đạt không?"}
    FAIL_CHECKLIST["❌ BadRequestException\n'Checklist chưa đạt,\nkhông thể bắt đầu chuyến'"]

    STATUS_CHECK{"Trip status\n= ASSIGNED hoặc ACCEPTED?"}
    WRONG_STATUS["❌ InvalidOperationException\n'Sai trạng thái chuyến'"]

    DRIVER_CHECK{"Driver.status\n= AVAILABLE?"}
    BUSY_DRIVER["❌ Driver đang bận\nhoặc bị đình chỉ"]

    START_TRIP["✅ Trip.status → IN_PROGRESS\nactualStartTime = now()"]
    START_SESSION["✅ DrivingSession.status → ACTIVE\nstartedAt = now()"]
    UPDATE_DRIVER["Driver.status → DRIVING"]
    UPDATE_VEHICLE["Vehicle.status → RUNNING"]
    TIMELINE["TripTimeline.action = STARTED\nactor = driver"]
    NOTIFY["NotificationService\nbroadcast(FLEET_MANAGER, DISPATCHER)\n'Chuyến X đã bắt đầu'"]
    WS["WebSocket STOMP\n/topic/trips broadcast"]

    REMEMBER["MobileCommandReceipt.save()\nclientEventId + response_json"]

    END(["🏁 MobileWorkflowResponse trả về tài xế"])

    START --> IDEMPOTENT
    IDEMPOTENT -->|"YES"| REPLAY
    IDEMPOTENT -->|"NO"| VEHICLE
    VEHICLE -->|"NO"| NO_VEHICLE
    VEHICLE -->|"YES"| CHECKLIST_EXIST
    CHECKLIST_EXIST -->|"NO"| NO_CHECKLIST
    CHECKLIST_EXIST -->|"YES"| CHECKLIST_PASS
    CHECKLIST_PASS -->|"NO"| FAIL_CHECKLIST
    CHECKLIST_PASS -->|"YES"| STATUS_CHECK
    STATUS_CHECK -->|"NO"| WRONG_STATUS
    STATUS_CHECK -->|"YES"| DRIVER_CHECK
    DRIVER_CHECK -->|"NO"| BUSY_DRIVER
    DRIVER_CHECK -->|"YES"| START_TRIP
    START_TRIP --> START_SESSION
    START_SESSION --> UPDATE_DRIVER
    UPDATE_DRIVER --> UPDATE_VEHICLE
    UPDATE_VEHICLE --> TIMELINE
    TIMELINE --> NOTIFY
    NOTIFY --> WS
    WS --> REMEMBER
    REMEMBER --> END
```

---

## 2. Activity: Gửi Cảnh Báo An Toàn (Safety Event)

> Nguồn: `SafetyEventService.java:create()`, `applySafetyScoreImpact()`

```mermaid
flowchart TD
    START(["📱 Flutter App phát hiện\nDROWSINESS / PHONE_USAGE / ..."])

    ONDEV_AI{"TFLite score ≥ 6\nhoặc Temporal rule trigger?"}
    IGNORE["⏭️ Bỏ qua\n(dưới ngưỡng cảnh báo)"]

    POST_API["POST /api/v1/mobile/safety-events\nBearer JWT\nclintEventId (UUID)"]

    IDEMPOTENT{"clientEventId\nđã tồn tại?"}
    REPLAY["↩️ Trả về event cũ\n(Idempotency)"]

    ROLE_CHECK{"Caller là\nDRIVER role?"}

    DRIVER_OWNER{"Driver ID\nkhớp với user hiện tại?"}
    FORBIDDEN["❌ ForbiddenActionException\n'Chỉ được gửi cảnh báo\ncủa chính mình'"]

    COOLDOWN{"event gần đây\ntrong ${cooldown:30}s?"}
    COOLDOWN_SKIP["↩️ Trả về event gần nhất\n(cooldown 30s)"]

    SAVE_EVENT["✅ SafetyEvent.save()\nstatus = NEW\nreceivedAt = now()"]

    SCORE_IMPACT["applySafetyScoreImpact()"]

    SEVERITY{"AlertSeverity?"}
    SCORE_LOW["safetyScore -= 2\n(LOW)"]
    SCORE_MED["safetyScore -= 5\n(MEDIUM)"]
    SCORE_HIGH["safetyScore -= 10\n(HIGH)"]
    SCORE_CRIT["safetyScore -= 20\n(CRITICAL)"]

    SCORE_MIN{"safetyScore ≤ 0?"}
    CLAMP_ZERO["safetyScore = 0"]

    SUSPENDED{"safetyScore < 50\n&& status ≠ SUSPENDED?"}
    SUSPEND_DRIVER["Driver.status → SUSPENDED\nNotify SAFETY_OFFICER"]

    PUBLISH["publishSafetyEvent()\nNotificationService.createGlobal()\nNotificationType.AI_ALERT\nWebSocket broadcast /topic/safety"]

    END(["🏁 SafetyEventResponse"])

    START --> ONDEV_AI
    ONDEV_AI -->|"NO"| IGNORE
    ONDEV_AI -->|"YES"| POST_API
    POST_API --> IDEMPOTENT
    IDEMPOTENT -->|"YES"| REPLAY
    IDEMPOTENT -->|"NO"| ROLE_CHECK
    ROLE_CHECK -->|"DRIVER"| DRIVER_OWNER
    ROLE_CHECK -->|"OTHER"| COOLDOWN
    DRIVER_OWNER -->|"NO"| FORBIDDEN
    DRIVER_OWNER -->|"YES"| COOLDOWN
    COOLDOWN -->|"YES"| COOLDOWN_SKIP
    COOLDOWN -->|"NO"| SAVE_EVENT
    SAVE_EVENT --> SCORE_IMPACT
    SCORE_IMPACT --> SEVERITY
    SEVERITY -->|"LOW"| SCORE_LOW
    SEVERITY -->|"MEDIUM"| SCORE_MED
    SEVERITY -->|"HIGH"| SCORE_HIGH
    SEVERITY -->|"CRITICAL"| SCORE_CRIT
    SCORE_LOW --> SCORE_MIN
    SCORE_MED --> SCORE_MIN
    SCORE_HIGH --> SCORE_MIN
    SCORE_CRIT --> SCORE_MIN
    SCORE_MIN -->|"YES"| CLAMP_ZERO
    SCORE_MIN -->|"NO"| SUSPENDED
    CLAMP_ZERO --> SUSPENDED
    SUSPENDED -->|"YES"| SUSPEND_DRIVER
    SUSPENDED -->|"NO"| PUBLISH
    SUSPEND_DRIVER --> PUBLISH
    PUBLISH --> END
```

---

## 3. Activity: Gửi SOS Khẩn Cấp

> Nguồn: `IncidentService.java:sos()`, `MobileAppService.java`

```mermaid
flowchart TD
    START(["🆘 Tài xế nhấn SOS"])

    AUTH["POST /api/v1/mobile/incidents/sos\nBearer JWT"]

    IDEMPOTENT{"clientEventId\nđã tồn tại?"}
    REPLAY["↩️ Trả về incident cũ"]

    COOLDOWN{"SOS trong\n${sos.cooldown:30}s?"}
    COOLDOWN_SKIP["↩️ Trả về SOS gần nhất"]

    DRIVER_OWN{"Caller = DRIVER?\nDriver ID hợp lệ?"}
    FORBIDDEN["❌ ForbiddenActionException\n'Chỉ được gửi SOS của mình'"]

    CREATE_INC["✅ Incident.save()\ntype = SOS\nseverity = CRITICAL\nstatus = OPEN\nincidentCode = INC-xxxx\nreceivedAt = now()"]

    TIMELINE["IncidentTimeline\naction = SOS_CREATED\n'SOS submitted from driver app'"]

    PUBLISH["publishIncident()\nNotificationType.SOS\nNotificationService.createGlobal()\nBroadcast đến: DISPATCHER, RESCUE_TEAM\nSAFETY_OFFICER, FLEET_MANAGER"]

    WS["WebSocket STOMP\n/topic/incidents\nReal-time alert"]

    END(["🏁 IncidentResponse trả về"])

    subgraph RESOLVE ["Xử lý phía Dispatcher/Rescue Team"]
        RES_ACCEPT["Dispatcher accept(id)\nincident.status → ACCEPTED\naddTimeline(ACCEPTED)"]
        RES_ASSIGN["assign(id, userId)\nincident.assignedTo = rescueUser"]
        RES_PROCESS["status → PROCESSING"]
        RES_CLOSE["close(id)\nstatus → RESOLVED / CLOSED\naddTimeline(RESOLVED)"]
    end

    START --> AUTH
    AUTH --> IDEMPOTENT
    IDEMPOTENT -->|"YES"| REPLAY
    IDEMPOTENT -->|"NO"| COOLDOWN
    COOLDOWN -->|"YES"| COOLDOWN_SKIP
    COOLDOWN -->|"NO"| DRIVER_OWN
    DRIVER_OWN -->|"FAIL"| FORBIDDEN
    DRIVER_OWN -->|"OK"| CREATE_INC
    CREATE_INC --> TIMELINE
    TIMELINE --> PUBLISH
    PUBLISH --> WS
    WS --> END
    END -.->|"Dispatcher nhận thông báo"| RES_ACCEPT
    RES_ACCEPT --> RES_ASSIGN
    RES_ASSIGN --> RES_PROCESS
    RES_PROCESS --> RES_CLOSE
```

---

## 4. Activity: Báo Cáo Điểm Ngập

> Nguồn: `FloodReportService.java:create()`, `warnNearby()`, `routeRisk()`

```mermaid
flowchart TD
    START(["🌊 Tài xế báo điểm ngập"])

    POST["POST /api/v1/mobile/flood-reports\nBearer JWT\nlat, lng, severity, imageUrl\nclientEventId"]

    IDEMPOTENT{"clientEventId đã tồn tại?"}
    REPLAY["↩️ Trả về report cũ"]

    DRIVER_CHECK{"Caller là DRIVER?\nDriver hợp lệ?"}
    FORBIDDEN["❌ ForbiddenActionException"]

    EXPIRY["expiredAt = now() +\nFLOOD_EXPIRATION_MINUTES\n(default: 180 phút = 3h)"]

    SAVE["✅ FloodReport.save()\nstatus = UNVERIFIED\nsource = DRIVER\nreceivedAt = now()"]

    CONFIDENCE["calculateConfidence()\nDựa trên: số báo cáo lân cận\nkhoảng cách\n→ score 0.0..0.99"]

    PUBLISH["broadcast()\nNotificationType.FLOOD\nWebSocket /topic/floods"]

    subgraph VERIFY ["Quy trình xác minh (SAFETY_OFFICER)"]
        V_CHECK{"Kiểm tra thực tế?"}
        V_VERIFY["verify(id)\nFloodStatus → VERIFIED\nverifiedBy = officer\nverifiedAt = now()"]
        V_REJECT["reject(id)\nFloodStatus → REJECTED"]
        V_RESOLVE["resolve(id)\nFloodStatus → RESOLVED"]
    end

    WARN["warnNearby(id)\nTìm driver trong bán kính\nDRIVER_WARNING_RADIUS_KM\nGửi notification cho từng driver"]

    ROUTE_RISK["routeRisk(route)\nKiểm tra intersection\nvới các FloodReport active\n→ RouteRiskSummaryResponse"]

    END(["🏁 FloodReportResponse"])

    START --> POST
    POST --> IDEMPOTENT
    IDEMPOTENT -->|"YES"| REPLAY
    IDEMPOTENT -->|"NO"| DRIVER_CHECK
    DRIVER_CHECK -->|"FAIL"| FORBIDDEN
    DRIVER_CHECK -->|"OK"| EXPIRY
    EXPIRY --> SAVE
    SAVE --> CONFIDENCE
    CONFIDENCE --> PUBLISH
    PUBLISH --> END
    END -.->|"Officer xem map"| V_CHECK
    V_CHECK -->|"Xác nhận"| V_VERIFY
    V_CHECK -->|"Sai"| V_REJECT
    V_VERIFY -.->|"Sau khi xử lý xong"| V_RESOLVE
    V_VERIFY -.->|"Cảnh báo lân cận"| WARN
    V_VERIFY -.->|"Navigation kiểm tra tuyến"| ROUTE_RISK
```

---

## 5. Activity: OCR Tài Liệu Phiếu Xuất Kho

> Nguồn: `DocumentOcrService.java`, `DocumentOcrJobService.java`, `run_hybrid.py`

```mermaid
flowchart TD
    START(["📷 Tài xế chụp ảnh\nPhiếu xuất kho"])

    UPLOAD["POST /api/v1/mobile/ocr/extract\nMultipart image\nmax 10MB\nBearer JWT"]

    SIZE_CHECK{"image ≤\nOCR_MAX_UPLOAD_BYTES\n(10MB)?"}
    TOO_BIG["❌ 413 Too Large"]

    SAVE_JOB["DocumentOcrJob.save()\nstatus = PROCESSING\nimage_data = BYTEA\nowner_user_id"]

    CALL_AI["POST http://ai-service:8000/ocr/extract\nX-SafeFleet-Service-Token\nMultipart image"]

    subgraph AI_OCR ["AI Service — Hybrid OCR Pipeline (run_hybrid.py)"]
        PREPROCESS["Image Preprocessing\nenhance_for_ocr()\nwarp_document()\nrotate_right_angle()\nchoose_orientation()"]
        TESSERACT["Tesseract OCR\n/usr/bin/tesseract\ntiếng Việt"]
        VIETOCR["VietOCR Transformer\n/models/vietocr/\nVietnamese text recognition"]
        MERGE["Merge kết quả\nchọn độ tin cậy cao hơn"]
        EXTRACT["Trích xuất field:\nvoucher_date · voucher_number\nvehicle_plate · driver_name\ntrip_count · project_address\n+ confidence scores [0..1]"]
    end

    UPDATE_JOB["DocumentOcrJob.update()\nstatus = COMPLETED\nvoucher_date, voucher_number\nvehicle_plate, driver_name\nvehicle_plate_confidence\nelapsed_ms"]

    PLATE_CHECK["Kiểm tra biển số\nplate_review_status\n= PLATE_MATCH / PLATE_MISMATCH\n/ NOT_CHECKED"]

    PLATE_MATCH{"vehicle_plate\nkhớp expected_vehicle_plate?"}
    MISMATCH_ALERT["plate_review_status = PLATE_MISMATCH\nNotify SAFETY_OFFICER để review"]
    MATCH_OK["plate_review_status = PLATE_MATCH"]

    REVIEW["DocumentPlateReviewService\nreview(id, note)\nreviewed_by_user_id\nreviewed_at = now()"]

    END(["🏁 DocumentOcrJobResponse\ntrả về tài xế"])

    START --> UPLOAD
    UPLOAD --> SIZE_CHECK
    SIZE_CHECK -->|"NO"| TOO_BIG
    SIZE_CHECK -->|"YES"| SAVE_JOB
    SAVE_JOB --> CALL_AI
    CALL_AI --> PREPROCESS
    PREPROCESS --> TESSERACT
    PREPROCESS --> VIETOCR
    TESSERACT --> MERGE
    VIETOCR --> MERGE
    MERGE --> EXTRACT
    EXTRACT --> UPDATE_JOB
    UPDATE_JOB --> PLATE_CHECK
    PLATE_CHECK --> PLATE_MATCH
    PLATE_MATCH -->|"NO"| MISMATCH_ALERT
    PLATE_MATCH -->|"YES"| MATCH_OK
    MATCH_OK --> END
    MISMATCH_ALERT -.->|"Officer kiểm tra"| REVIEW
    REVIEW -.-> END
```

---

## 6. Activity: AI Voice Agent — Data Query

> Nguồn: `MobileAppService.java:submitAgentCommand()`, `AgentOrchestrator.py`

```mermaid
flowchart TD
    START(["🎤 Tài xế nói lệnh\nspeech_to_text → text"])

    POST_INTENT["POST /api/v1/mobile/agent/intent/classify\nX-SafeFleet-Service-Token\ntranscript"]

    LOCAL_RULES{"Local rules\nmatch (8 rules)?"}
    LOCAL_RESULT["confidence = 0.95\nsource = LOCAL_RULE"]

    OPENAI_EN{"OPENAI_ENABLED\n= true?"}
    GPT_CALL["gpt-4o-mini\nstructured_response\nmax_tokens = 200"]
    FALLBACK["Intent = UNKNOWN\nconfidence = 0.0"]

    AGENT_CMD["AgentCommand.save()\nstatus = RECEIVED\ninterpretedIntent\nclassificationSource"]

    CONFIRM_REQ{"requires_\nconfirmation?"}

    subgraph NO_CONFIRM ["Lệnh không cần xác nhận\n(GET_DRIVING_TIME, READ_WARNING)"]
        EXEC_DIRECT["Thực thi trực tiếp\n→ AgentCommand.status = EXECUTED"]
        RETURN_RESULT["Trả kết quả ngay"]
    end

    subgraph CONFIRM_FLOW ["Lệnh cần xác nhận\n(START_TRIP, SOS, FLOOD...)"]
        SHOW_CONFIRM["App hiển thị xác nhận\n'Bạn có muốn X không?'"]
        USER_CHOICE{"Tài xế\nxác nhận?"}
        EXEC_CMD["POST /mobile/agent/commands/{id}/confirm\n→ thực thi thực sự"]
        CANCEL_CMD["AgentCommand.status = CANCELLED"]
    end

    subgraph DATA_AGENT ["Data Agent (OPENAI query)"]
        PREFLIGHT["Pre-flight checks\nrequests_other_driver? → từ chối\nrequests_weather? → từ chối\nneed_scope? → hỏi lại"]
        CREATE_PLAN["_create_plan()\ngpt-4o-mini → Plan"]
        AGENT_LOOP["Loop ≤ max_steps (6)\ngpt-4o-mini tool_choice=auto\n→ tool_calls"]
        MCP_EXEC["MCP execute tool\nlist_trips / get_trip_detail\nget_monthly_report"]
        BACKEND_HTTP["GET /api/v1/mobile/trips\nGET /api/v1/mobile/activity/monthly\ntimeout: 15s"]
        SYNTHESIZE["gpt-4o-mini tổng hợp\nkết quả trả lời"]
    end

    END_INTENT(["🏁 IntentResponse → App"])
    END_AGENT(["🏁 AgentChatResponse\ntrả lời tổng hợp"])

    START --> POST_INTENT
    POST_INTENT --> LOCAL_RULES
    LOCAL_RULES -->|"MATCH"| LOCAL_RESULT
    LOCAL_RULES -->|"NO MATCH"| OPENAI_EN
    OPENAI_EN -->|"false"| FALLBACK
    OPENAI_EN -->|"true"| GPT_CALL
    GPT_CALL --> LOCAL_RESULT
    LOCAL_RESULT --> AGENT_CMD
    FALLBACK --> AGENT_CMD

    AGENT_CMD --> CONFIRM_REQ
    CONFIRM_REQ -->|"NO"| NO_CONFIRM
    CONFIRM_REQ -->|"YES"| CONFIRM_FLOW

    EXEC_DIRECT --> RETURN_RESULT
    RETURN_RESULT --> END_INTENT

    SHOW_CONFIRM --> USER_CHOICE
    USER_CHOICE -->|"Có"| EXEC_CMD
    USER_CHOICE -->|"Không"| CANCEL_CMD
    EXEC_CMD --> END_INTENT

    AGENT_CMD -.->|"Query loại\nDATA/REPORT"| PREFLIGHT
    PREFLIGHT --> CREATE_PLAN
    CREATE_PLAN --> AGENT_LOOP
    AGENT_LOOP --> MCP_EXEC
    MCP_EXEC --> BACKEND_HTTP
    BACKEND_HTTP --> AGENT_LOOP
    AGENT_LOOP --> SYNTHESIZE
    SYNTHESIZE --> END_AGENT
```

---

## Bảng Nguồn Source Code

| Activity | File nguồn | Các điểm quan trọng từ code |
|---|---|---|
| Trip Start Workflow | `mobile/service/MobileAppService.java:457` | idempotency replay, checklist gate, vehicle check, MobileCommandReceipt.save() |
| Checklist gate | `MobileAppService.java:468-472` | `checklistPassed()` — bắt buộc trước khi start |
| Safety Event cooldown | `safety/service/SafetyEventService.java:55-56` | `@Value("${app.safety.cooldown-seconds:30}")` |
| Safety score penalty | `SafetyEventService.java:244-256` | LOW:-2, MED:-5, HIGH:-10, CRIT:-20; suspend if <50 |
| SOS cooldown | `incident/service/IncidentService.java:63` | `@Value("${app.sos.cooldown-seconds:30}")` |
| SOS idempotency | `IncidentService.java:123-126` | clientEventId lookup → return existing |
| Flood expiry | `flood/service/FloodReportService.java:81` | `FLOOD_EXPIRATION_MINUTES` default 180 phút |
| Flood confidence | `FloodReportService.java:187-204` | nearby reports count + verified bonus |
| OCR max upload | `safefleet_ai/service/core/security.py` + `.env` | `OCR_MAX_UPLOAD_BYTES=10485760` (10MB) |
| OCR pipeline | `ocr/pipeline/run_hybrid.py` | `enhance_for_ocr` + `warp_document` + Tesseract + VietOCR |
| Agent max steps | `agent/orchestrator.py:105` | `while step_index < configuration.max_steps` (default 6) |
| Agent confirmation | `agent/orchestrator.py:170-179` | `AWAITING_CONFIRMATION` — stop loop |
| Intent local rules | `intent/rules.py:8-17` | 8 rules, confidence=0.95 |
| Intent OpenAI schema | `intent/service.py:13-21` | Structured JSON schema, max_output_tokens=200 |
