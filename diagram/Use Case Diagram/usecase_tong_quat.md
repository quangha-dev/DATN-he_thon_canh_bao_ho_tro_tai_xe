# Use Case Diagram Tổng Quát — SafeFleet

> **Nguồn:** Toàn bộ use case được trích xuất từ `@PreAuthorize` trong các controller thực tế.
> Actors dựa trên `RoleName.java`: `ADMIN, FLEET_MANAGER, DISPATCHER, SAFETY_OFFICER, RESCUE_TEAM, DRIVER`

---

## Biểu Đồ Tổng Quát

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "14px"}}}%%
graph LR
    %% ════ ACTORS ════
    DRIVER(["👤 Tài xế\n(DRIVER)"])
    DISPATCHER(["👤 Điều phối viên\n(DISPATCHER)"])
    FLEET_MGR(["👤 Quản lý đội xe\n(FLEET_MANAGER)"])
    SAFETY_OFF(["👤 Cán bộ an toàn\n(SAFETY_OFFICER)"])
    RESCUE(["👤 Đội cứu hộ\n(RESCUE_TEAM)"])
    ADMIN(["👤 Quản trị viên\n(ADMIN)"])

    %% ════ USE CASE GROUPS ════
    subgraph UC_AUTH ["🔐 UC01: Xác thực hệ thống"]
        UC1_1["Đăng nhập / Làm mới token"]
        UC1_2["Đổi mật khẩu"]
        UC1_3["Xem hồ sơ cá nhân"]
    end

    subgraph UC_DRIVE ["🚗 UC02: Quản lý lái xe"]
        UC2_1["Quản lý chuyến đi (Trip)"]
        UC2_2["Quản lý phiên lái xe (Driving Session)"]
        UC2_3["Gửi telemetry GPS"]
        UC2_4["Điều hướng bản đồ"]
        UC2_5["Xem thời gian lái xe còn lại"]
    end

    subgraph UC_SAFETY ["⚠️ UC03: An toàn tài xế"]
        UC3_1["Gửi sự kiện an toàn (buồn ngủ...)"]
        UC3_2["Báo động SOS khẩn cấp"]
        UC3_3["Upload bằng chứng sự cố (Evidence)"]
        UC3_4["Xem & giám sát sự kiện an toàn"]
        UC3_5["Tính lại điểm an toàn tài xế"]
    end

    subgraph UC_FLOOD ["🌊 UC04: Cảnh báo ngập lụt"]
        UC4_1["Báo điểm ngập (nhanh / đầy đủ)"]
        UC4_2["Xem bản đồ điểm ngập lân cận"]
        UC4_3["Kiểm tra rủi ro tuyến đường"]
        UC4_4["Quản lý vùng ngập (CRUD)"]
        UC4_5["Phát cảnh báo ngập đến xe gần đó"]
    end

    subgraph UC_INCIDENT ["🚨 UC05: Quản lý sự cố"]
        UC5_1["Tạo sự cố mới"]
        UC5_2["Xem & tìm kiếm sự cố"]
        UC5_3["Chấp nhận / Phân công sự cố"]
        UC5_4["Cập nhật tiến trình (Timeline)"]
        UC5_5["Đóng sự cố"]
    end

    subgraph UC_FLEET ["🚚 UC06: Quản lý đội xe"]
        UC6_1["Quản lý xe (CRUD)"]
        UC6_2["Quản lý tài xế (CRUD)"]
        UC6_3["Xem vị trí xe thời gian thực"]
        UC6_4["Quản lý bảo dưỡng xe"]
        UC6_5["Điều phối chuyến xe"]
    end

    subgraph UC_DOC ["📄 UC07: OCR & Tài liệu"]
        UC7_1["Scan tài liệu / biển số xe (OCR)"]
        UC7_2["Duyệt / Từ chối tài liệu"]
        UC7_3["Xem kết quả OCR"]
    end

    subgraph UC_AI ["🤖 UC08: AI Agent"]
        UC8_1["Gửi lệnh điều phối bằng giọng nói/văn bản"]
        UC8_2["Xác nhận / Huỷ lệnh AI"]
        UC8_3["Xem lịch sử lệnh AI"]
        UC8_4["Cấu hình AI Agent"]
    end

    subgraph UC_REPORT ["📊 UC09: Báo cáo & Dashboard"]
        UC9_1["Xem dashboard tổng quan"]
        UC9_2["Báo cáo tài xế / phương tiện"]
        UC9_3["Báo cáo ngập lụt / sự cố"]
    end

    subgraph UC_ADMIN ["⚙️ UC10: Quản trị hệ thống"]
        UC10_1["Quản lý tài khoản người dùng"]
        UC10_2["Cấu hình tham số hệ thống"]
        UC10_3["Cấu hình AI Agent"]
    end

    subgraph UC_NOTIF ["🔔 UC11: Thông báo"]
        UC11_1["Nhận & xem thông báo"]
        UC11_2["Đăng ký / Huỷ push token (FCM)"]
    end

    %% ════ DRIVER USES ════
    DRIVER --- UC_AUTH
    DRIVER --- UC_DRIVE
    DRIVER --- UC_SAFETY
    DRIVER --- UC_FLOOD
    DRIVER --- UC_DOC
    DRIVER --- UC_AI
    DRIVER --- UC_NOTIF

    %% ════ DISPATCHER USES ════
    DISPATCHER --- UC_AUTH
    DISPATCHER --- UC_FLEET
    DISPATCHER --- UC_INCIDENT
    DISPATCHER --- UC_FLOOD
    DISPATCHER --- UC_AI
    DISPATCHER --- UC_NOTIF
    DISPATCHER --- UC_REPORT

    %% ════ FLEET_MGR USES ════
    FLEET_MGR --- UC_AUTH
    FLEET_MGR --- UC_FLEET
    FLEET_MGR --- UC_INCIDENT
    FLEET_MGR --- UC_FLOOD
    FLEET_MGR --- UC_REPORT
    FLEET_MGR --- UC_NOTIF

    %% ════ SAFETY_OFF USES ════
    SAFETY_OFF --- UC_AUTH
    SAFETY_OFF --- UC_SAFETY
    SAFETY_OFF --- UC_INCIDENT
    SAFETY_OFF --- UC_FLEET
    SAFETY_OFF --- UC_REPORT
    SAFETY_OFF --- UC_NOTIF

    %% ════ RESCUE USES ════
    RESCUE --- UC_AUTH
    RESCUE --- UC_INCIDENT
    RESCUE --- UC_NOTIF

    %% ════ ADMIN USES ════
    ADMIN --- UC_AUTH
    ADMIN --- UC_ADMIN
    ADMIN --- UC_FLEET
    ADMIN --- UC_INCIDENT
    ADMIN --- UC_REPORT
    ADMIN --- UC_NOTIF
```

---

## Bảng Phân Quyền Actor – Use Case (từ `@PreAuthorize`)

| Use Case | ADMIN | FLEET_MGR | DISPATCHER | SAFETY_OFF | RESCUE | DRIVER |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Xác thực** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Quản lý lái xe (Trip, Telemetry)** | ✅ | ✅ | ✅ | — | — | ✅ |
| **An toàn (Safety Events, SOS)** | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| **Ngập lụt (báo cáo, kiểm tra)** | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| **Sự cố (xem)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Sự cố (xử lý, phân công, đóng)** | ✅ | — | ✅ | — | ✅ | — |
| **Quản lý xe / tài xế (xem)** | ✅ | ✅ | ✅ | ✅ | — | — |
| **Quản lý xe / tài xế (CRUD)** | ✅ | ✅ | — | — | — | — |
| **Bảo dưỡng xe** | ✅ | ✅ | ✅ | — | — | — |
| **OCR tài liệu (scan)** | — | — | — | — | — | ✅ |
| **OCR tài liệu (duyệt)** | ✅ | ✅ | ✅ | — | — | — |
| **AI Agent (gửi lệnh)** | ✅ | — | ✅ | — | — | ✅ |
| **AI Agent (cấu hình)** | ✅ | — | — | — | — | — |
| **Báo cáo & Dashboard** | ✅ | ✅ | ✅ | ✅ | ✅* | — |
| **Cấu hình hệ thống** | ✅ | ✅** | — | — | — | — |
| **Quản lý tài khoản** | ✅ | — | — | — | — | — |

> *RESCUE_TEAM chỉ xem báo cáo sự cố (`ReportController.java:83 @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER','RESCUE_TEAM')")`)
> **FLEET_MANAGER chỉ xem cấu hình, không sửa (chỉ ADMIN được `PUT /settings/{key}`)
