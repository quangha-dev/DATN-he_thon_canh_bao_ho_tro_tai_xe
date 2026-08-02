# SafeFleet Docker Runbook

## Chuẩn bị

```powershell
Copy-Item .env.example .env
```

Đổi mọi giá trị `change_me`. Không commit `.env`. MySQL host mặc định dùng `3307`; trong Docker backend dùng `mysql:3306`.

## Validate, build và chạy

```powershell
docker compose config --quiet
docker compose build
docker compose up -d
docker compose ps
.\docker\scripts\health-check.ps1
node .\docker\scripts\websocket-smoke.mjs
```

Kỳ vọng:

- `mysql`, `backend`, `frontend`, `ai-service`, `minio`: `healthy`.
- Backend/web/AI/MinIO: HTTP 200.
- WebSocket: JWT `CONNECTED`, anonymous `ERROR`.

## URL

| Dịch vụ | URL |
|---|---|
| Web | `http://localhost:3000` |
| Backend | `http://localhost:8080` |
| Swagger | `http://localhost:8080/swagger-ui/index.html` |
| AI | `http://localhost:8000` |
| MinIO | `http://localhost:9000`; console `http://localhost:9001` |
| MySQL host | `127.0.0.1:3307` |

## Volume

- `mysql_data`: dữ liệu nghiệp vụ/Flyway.
- `minio_data`: object evidence mặc định trong bucket private.
- `evidence_data`: chỉ dùng khi cấu hình fallback `EVIDENCE_STORAGE_PROVIDER=local`.

Backend mặc định kết nối `http://minio:9000`; `minio-init` tạo bucket private trước khi backend khởi động. Backend image vẫn tạo `/data/evidence` với đúng owner non-root cho chế độ fallback. Nếu nâng cấp từ image cũ có volume root-owned:

```powershell
docker compose run --rm --no-deps --user root --entrypoint chown backend -R safefleet:safefleet /data/evidence
docker compose up -d backend
```

## Backup/restore

```powershell
.\docker\scripts\db-backup.ps1
.\docker\scripts\db-verify-backup-restore.ps1 -InputPath <duong-dan-file.sql>
.\docker\scripts\db-restore.ps1 -InputPath <duong-dan-file.sql>
```

`db-backup` từ chối giữ dump lỗi/nhỏ bất thường. Script verify restore vào database tạm, so chữ ký dữ liệu rồi tự dọn sạch. `db-restore` thay đổi database hiện hành và yêu cầu nhập chính xác `RESTORE-SAFEFLEET`.

## Dừng

Giữ dữ liệu:

```powershell
docker compose down
```

Reset local có xác nhận:

```powershell
.\docker\scripts\reset-local.ps1
```

Không dùng `docker compose down -v` trừ khi chủ ý xóa toàn bộ volume local.

## Tạo lại báo cáo API

Khi backend đang healthy:

```powershell
node .\docker\scripts\export-api-report.mjs
```

Script lấy trực tiếp `/v3/api-docs` và cập nhật báo cáo root với toàn bộ path/input/output/schema.
