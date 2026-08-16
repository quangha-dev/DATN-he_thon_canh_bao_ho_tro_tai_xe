# Bộ tài liệu cốt lõi SafeFleet

Thư mục này chỉ giữ các tài liệu còn cần cho báo cáo, kiểm chứng và vận hành hệ thống.

## Báo cáo và kiểm chứng

- `REQUIREMENT_TRACEABILITY.md`: truy vết yêu cầu đến chức năng và kiểm thử.
- `QUALITY_SCORECARD.md`: trạng thái chất lượng và mức độ hoàn thiện.
- `DATABASE_VERIFICATION.md`: kiểm chứng database và backup/restore.
- `API_MOBILE_CONTRACT.md`: hợp đồng API giữa mobile và backend.

## Kiến trúc chức năng

- `SAFEFLEET_AGENT_MCP.md`: kiến trúc agent và MCP tool.
- `report-diagrams/CH2-DIAGRAM-*.svg`: chín sơ đồ được dùng trong báo cáo chính.
- `report-diagrams/sources/CH2-DIAGRAM-*.mmd`: nguồn Mermaid để sửa hoặc render lại sơ đồ.

## PostgreSQL

- `database/postgresql/README.md`: quyết định kiến trúc dữ liệu đích.
- `database/postgresql/V1__postgresql_baseline.sql`: baseline nghiệp vụ.
- `database/postgresql/V2__rag_and_agent.sql`: RAG và agent trace.
- `database/postgresql/V3__postgis.sql`: dữ liệu địa lý.
- `database/postgresql/MIGRATION_RUNBOOK.md`: kế hoạch chuyển đổi/rollback.
- `database/postgresql/MYSQL_TO_POSTGRES_COMPATIBILITY.md`: thay đổi code bắt buộc.
- `database/postgresql/VALIDATION_REPORT.md`: kết quả chạy kiểm chứng DDL.

## Vận hành

- `DOCKER_RUNBOOK.md`: khởi động và kiểm tra hệ thống Docker.

Các tài liệu nháp/audit cũ đã được chuyển ra kho lưu trữ ngoài dự án thay vì xóa vĩnh viễn.
