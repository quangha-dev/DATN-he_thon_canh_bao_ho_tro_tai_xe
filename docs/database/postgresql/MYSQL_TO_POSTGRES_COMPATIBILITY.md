# Ma trận tương thích MySQL → PostgreSQL

## Thay đổi cấu hình/dependency

| Hạng mục | Hiện tại | Đích |
|---|---|---|
| JDBC URL | `jdbc:mysql://...` | `jdbc:postgresql://postgres:5432/safefleet?currentSchema=safefleet` |
| Hibernate dialect | `MySQLDialect` | `PostgreSQLDialect` hoặc để Hibernate tự nhận |
| Maven JDBC | MySQL Connector/J | `org.postgresql:postgresql` |
| Docker service | `mysql:8.4` | image PostgreSQL 16 có pgvector + PostGIS |
| Healthcheck | `mysqladmin ping` | `pg_isready` |
| Testcontainer | `MySQLContainer` | `PostgreSQLContainer`/compatible image |
| Flyway | migration V1–V13 MySQL | baseline PostgreSQL mới trong location/profile riêng |

Không đặt migration MySQL và PostgreSQL cùng location khi cả hai có cùng version `V1`, `V2`. Trong nhánh chuyển đổi, dùng location theo vendor, ví dụ:

- `db/migration/mysql` (legacy, chỉ để rollback/đọc lịch sử);
- `db/migration/postgresql` (đích).

## Truy vấn native phải đổi

### Push notification upsert

MySQL:

```sql
INSERT ... ON DUPLICATE KEY UPDATE ...
```

PostgreSQL:

```sql
INSERT ...
ON CONFLICT (provider, token)
DO UPDATE SET enabled = EXCLUDED.enabled,
              updated_at = now();
```

### Đọc khoảng cách trong JSON route

MySQL:

```sql
CAST(JSON_UNQUOTE(JSON_EXTRACT(planned_route_json, '$.route.distanceKm')) AS DECIMAL(12,2))
```

PostgreSQL:

```sql
NULLIF(planned_route_json #>> '{route,distanceKm}', '')::numeric(12,2)
```

`LIMIT 1` dùng được ở PostgreSQL, nhưng truy vấn “bản ghi gần nhất” phải có `ORDER BY` xác định để tránh kết quả ngẫu nhiên.

## Mapping entity/JPA

| Mapping cũ | Mapping đích |
|---|---|
| `columnDefinition = "json"` | Hibernate 6 `@JdbcTypeCode(SqlTypes.JSON)` + cột `jsonb` |
| `LONGTEXT/MEDIUMTEXT` | `text`; bỏ columnDefinition phụ thuộc vendor |
| `MEDIUMBLOB image_data` | bỏ field byte[]; dùng `sourceAssetId`/quan hệ `ObjectAsset` |
| `LocalDateTime` cho thời điểm tuyệt đối | ưu tiên `Instant` hoặc `OffsetDateTime` |
| `Double` lat/lng | vẫn giữ trong API, DB thêm PostGIS projection |
| current driver/vehicle/device fields | repository đọc bảng assignment đang hoạt động |

Không dùng Hibernate `ddl-auto=update` trong production. Flyway phải là nguồn schema duy nhất; `ddl-auto=validate` để phát hiện entity lệch DDL.

## Thay đổi OCR bắt buộc

API/service cần tách hai state machine:

```text
ocr_status:    QUEUED → PROCESSING → SUCCEEDED | FAILED | CANCELLED
record_status: WAITING_OCR | NEEDS_REVIEW | COMPLETE | DELETED
```

- “Lưu thông tin bổ sung” chỉ ghi `manual_fields`, tăng `version`, tính lại `record_status`.
- Worker OCR chỉ ghi `ocr_fields`, trường extracted/confidence và `ocr_status`.
- Merge dùng optimistic locking; không được update toàn entity bằng snapshot cũ vì sẽ ghi đè dữ liệu phía còn lại.
- Xóa phiếu gửi nhầm đặt `deleted=true`/`record_status=DELETED`; worker phải kiểm tra trước khi commit kết quả.

## Chống nhận phiếu của tài xế khác

Khi OCR xong biển số:

1. Chuẩn hóa biển số (uppercase, bỏ dấu cách/gạch/chấm để so sánh; vẫn giữ bản gốc để hiển thị).
2. Tìm `driver_vehicle_assignments` của tài xế tại `voucher_date/captured_at`.
3. Nếu khớp: `plate_review_status=MATCHED`.
4. Nếu khác/không có phân công: `REVIEW_REQUIRED`, tạo notification cho quyền quản lý phù hợp.
5. Quản lý phê duyệt/từ chối; mọi quyết định ghi audit, không sửa thầm biển số OCR.

## RAG và phân quyền

- Backend/safefleet_ai phải lọc `rag_access_grants` trước hoặc trong cùng truy vấn retrieval.
- Tool MCP chỉ được gọi nếu `permission_snapshot` của run có quyền tương ứng.
- RAG không được làm nguồn sự thật cho trạng thái chuyến; trạng thái nghiệp vụ luôn lấy từ bảng quan hệ/tool nghiệp vụ.
- Prompt, tool input/output trước khi lưu phải loại API key, access token và dữ liệu bí mật không cần thiết.

## Checklist kiểm thử

- Khởi tạo PostgreSQL sạch bằng Flyway.
- Integration test cho mọi native query/upsert/JSON.
- Test timezone quanh 00:00 Việt Nam và ngày chuyển tháng/năm.
- Test unique không phân biệt hoa thường cho username/email/biển số.
- Test idempotency khi mobile gửi lại batch.
- Test đồng thời worker OCR và người dùng lưu bổ sung, đảm bảo không mất dữ liệu/không dừng job.
- Test MinIO lỗi tạm thời và retry không tạo object/job trùng.
- Test PostGIS khoảng cách, tuyến cắt vùng ngập.
- Test vector + keyword hybrid retrieval có lọc quyền.
- Test backup/restore PostgreSQL và MinIO như một cặp nhất quán.
