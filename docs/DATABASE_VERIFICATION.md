# SafeFleet — Database Verification

## Kết luận

- MySQL thật: `mysql:8.4`, host local `127.0.0.1:3307`.
- Hibernate: `ddl-auto=validate`; không dùng H2.
- Flyway V1–V7 đều validate/migrate thành công trên schema sạch.
- Backend: 25/25 test PASS, trong đó 9 bài integration dựng schema sạch trên Testcontainers MySQL 8.4.
- E2E Docker app/API → MySQL → API quản lý: PASS ngày 27/07/2026; full stack đã rebuild lại sau V7 và health/WebSocket PASS.
- Restart MySQL/backend/MinIO không làm mất DB hoặc object evidence.

## Bằng chứng E2E mới nhất

Dữ liệu được gửi qua HTTP thật bằng `driver01`, sau đó đối chiếu trực tiếp MySQL trong container.

### Safety chống giả mạo và chống trùng

```text
id  client_event_id                driver_id
17  docker-safety-1785092858727    1
```

Payload cố tình truyền `driverId` của tài xế khác nhưng bản ghi vẫn thuộc driver lấy từ JWT. Gửi lại cùng `clientEventId` trả đúng `id=17`.

### Evidence MinIO private

```text
id  size_bytes  sha256
2   1443        3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180
```

- Upload PNG thật qua multipart.
- SHA-256 của source, API metadata và file tải về khớp hoàn toàn.
- `mc stat` xác nhận object tồn tại trong bucket `safefleet-evidence`.
- HTTP trực tiếp không credential đến object trả 403.
- Chủ sở hữu tải được 1.443 byte.
- Tài xế khác nhận HTTP 403.
- Sau restart MinIO và backend vẫn tải được đúng hash.

### Flood và workflow idempotency

```text
flood client_event_id                                      rows  id
docker-flood-2b4e3edac56c4527a42788d19ba98b10             1     11

workflow trip_id  operation  receipts  driving_sessions  navigation_sessions
11                START      1         1                 1
11                COMPLETE   1         1                 1
```

Hai request flood cùng `clientEventId` trả cùng ID và `receivedAt` có giá trị. Replay start/complete trả cùng workflow response, không tạo thêm timeline/session.

### SOS và timeline

```text
id  status    client_event_id
7   ACCEPTED  docker-sos-1785092858727
```

Gửi lại cùng `clientEventId` trả cùng incident ID. Admin accept qua API; app đọc lại trạng thái `ACCEPTED` và timeline.

### Push fallback

```text
status             item_count
POLLING_FALLBACK   2
```

Khi `FCM_ENABLED=false`, worker không làm mất notification mà chuyển về polling REST.

### Flyway

```text
flyway_version
7
```

Migration:

1. `V1__init_schema.sql`
2. `V2__seed_reference_data.sql`
3. `V3__add_mobile_driver_app_support.sql`
4. `V4__offline_navigation_evidence_and_push.sql`
5. `V5__navigation_scoring_and_batch_ack.sql`
6. `V6__mobile_workflow_idempotency.sql`
7. `V7__agent_intent_confirmation.sql`

Không sửa migration đã áp dụng; thay đổi schema tiếp theo phải tạo `V8__...`.

### Backup và restore

`docker/scripts/db-verify-backup-restore.ps1` đã tạo database tạm, restore dump, đối chiếu và dọn sạch:

```text
backup_bytes       117313
backup_sha256      616404814fd5f225bed9f41c26157c34b93da929024635dd6e38c8ad819d6406
source_signature   20|15|20|11|18|7|11|2|2|7|11|2
restore_signature  20|15|20|11|18|7|11|2|2|7|11|2
temp_db_remaining  0
```

## Query kiểm tra lặp lại

Nạp credential từ `.env`, không ghi password vào tài liệu/log:

```sql
SELECT MAX(version) FROM flyway_schema_history WHERE success = 1;
SELECT id, client_event_id, driver_id FROM safety_events ORDER BY id DESC LIMIT 10;
SELECT id, CHAR_LENGTH(sha256), size_bytes FROM safety_event_evidence ORDER BY id DESC LIMIT 10;
SELECT id, status, client_event_id FROM incidents ORDER BY id DESC LIMIT 10;
SELECT status, COUNT(*) FROM pending_push_notifications GROUP BY status;
```

Không lưu access token, refresh token, JWT secret hoặc database password trong file bằng chứng.
