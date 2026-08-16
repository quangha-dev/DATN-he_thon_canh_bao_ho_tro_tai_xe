# Báo cáo kiểm tra thiết kế PostgreSQL

Ngày kiểm tra: 2026-08-14

## Môi trường

- PostgreSQL 16, image nền `pgvector/pgvector:pg16`.
- pgvector được cung cấp bởi image.
- PostGIS 3.6.4 được cài trong container kiểm tra tạm thời.
- Database kiểm tra sạch: `safefleet_design`.
- `psql -v ON_ERROR_STOP=1` để dừng ngay tại lỗi đầu tiên.

Container chỉ dùng để kiểm tra và không gắn volume dữ liệu production.

## Kết quả

| Kiểm tra | Kết quả |
|---|---|
| Chạy `V1__postgresql_baseline.sql` | PASS |
| Chạy `V2__rag_and_agent.sql` | PASS |
| Chạy `V3__postgis.sql` | PASS |
| Extension `pgcrypto` | PASS |
| Extension `pg_trgm` | PASS |
| Extension `vector` | PASS |
| Extension `postgis` | PASS, version 3.6.4 |
| Bảng MySQL nghiệp vụ có mapping | 41/41 |
| Tổng bảng PostgreSQL đích | 54 |
| Bảng mới phục vụ assignment/object/RAG/agent | 13 |
| Cột PostGIS geometry/geography tạo thành công | 11 |

Không có bảng nghiệp vụ MySQL nào bị bỏ quên. 13 bảng mới là:

- `driver_vehicle_assignments`, `vehicle_device_assignments`;
- `object_assets`;
- `rag_collections`, `rag_documents`, `rag_document_versions`, `rag_chunks`, `rag_ingestion_jobs`, `rag_access_grants`;
- `ai_conversations`, `ai_messages`, `ai_agent_runs`, `ai_tool_calls`.

## Phạm vi chưa phải là kiểm thử migration dữ liệu

Kết quả trên xác nhận DDL, extension, ràng buộc và coverage bảng. Nó chưa chứng minh dữ liệu MySQL thực tế đã chuyển đúng, vì cutover chưa được thực hiện. Trước chuyển thật vẫn phải chạy:

- ETL thử trên bản sao dữ liệu;
- đối soát count/checksum/status/timezone;
- upload và kiểm tra SHA-256 của BLOB OCR trên MinIO;
- integration test backend PostgreSQL;
- smoke/E2E web, mobile, OCR và agent;
- diễn tập backup/restore và rollback.
