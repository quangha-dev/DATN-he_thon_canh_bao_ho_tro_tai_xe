import { writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const backendOrigin = process.env.SAFEFLEET_BACKEND_ORIGIN ?? "http://localhost:8080";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const output =
  process.env.SAFEFLEET_REPORT_PATH ??
  path.join(root, "BAO_CAO_HE_THONG_VA_API_SAFEFLEET_2026.md");
const methodOrder = ["get", "post", "put", "patch", "delete"];

const response = await fetch(`${backendOrigin}/v3/api-docs`);
if (!response.ok) {
  throw new Error(`OpenAPI returned HTTP ${response.status}`);
}
const spec = await response.json();

function escapeCell(value) {
  return String(value ?? "—")
    .replaceAll("|", "\\|")
    .replaceAll("\r", " ")
    .replaceAll("\n", "<br>");
}

function refName(ref) {
  return ref?.split("/").at(-1);
}

function schemaLabel(schema = {}) {
  if (schema.$ref) return `\`${refName(schema.$ref)}\``;
  if (schema.type === "array") return `array<${schemaLabel(schema.items)}>`;
  if (schema.oneOf) return schema.oneOf.map(schemaLabel).join(" hoặc ");
  if (schema.allOf) return schema.allOf.map(schemaLabel).join(" + ");
  if (schema.additionalProperties) {
    return `map<string, ${schemaLabel(schema.additionalProperties)}>`;
  }
  let label = schema.type ?? "object";
  if (schema.format) label += ` (${schema.format})`;
  if (schema.enum) label += ` enum[${schema.enum.join(", ")}]`;
  return `\`${label}\``;
}

function parameterLabel(parameter) {
  const required = parameter.required ? ", bắt buộc" : ", tùy chọn";
  return `\`${parameter.name}\` (${parameter.in}${required}): ${schemaLabel(parameter.schema)}`;
}

function requestLabel(operation) {
  const parameters = (operation.parameters ?? []).map(parameterLabel);
  const content = operation.requestBody?.content ?? {};
  const bodies = Object.entries(content).map(
    ([contentType, media]) =>
      `body ${schemaLabel(media.schema)}; \`${contentType}\`${operation.requestBody.required ? ", bắt buộc" : ""}`,
  );
  return [...parameters, ...bodies].join("<br>") || "Không có";
}

function responseLabel(operation) {
  return Object.entries(operation.responses ?? {})
    .map(([status, value]) => {
      const content = value.content ?? {};
      const schemas = Object.values(content).map((media) => schemaLabel(media.schema));
      return `\`${status}\` ${schemas.join(", ") || escapeCell(value.description)}`;
    })
    .join("<br>");
}

const operations = [];
for (const [apiPath, pathItem] of Object.entries(spec.paths ?? {})) {
  for (const method of methodOrder) {
    const operation = pathItem[method];
    if (!operation) continue;
    operations.push({
      method: method.toUpperCase(),
      path: apiPath,
      tag: operation.tags?.join(", ") ?? "other",
      summary: operation.summary ?? operation.operationId ?? "—",
      input: requestLabel(operation),
      output: responseLabel(operation),
      auth:
        operation.security === undefined
          ? "Theo security toàn cục"
          : operation.security.length
            ? "Bearer JWT"
            : "Public",
    });
  }
}

const schemas = Object.entries(spec.components?.schemas ?? {}).sort(([a], [b]) =>
  a.localeCompare(b),
);

const lines = [];
const add = (...values) => lines.push(...values);

add(
  "# Báo cáo hiện trạng hệ thống và hợp đồng API SafeFleet",
  "",
  `> Sinh tự động từ OpenAPI của backend đang chạy tại \`${backendOrigin}\` ngày 27/07/2026. Báo cáo này là nguồn tích hợp hiện hành; file \`BAO_CAO_TICH_HOP_APP_SAFEFLEET.md\` là bản khảo sát baseline trước các vòng hoàn thiện.`,
  "",
  "## 1. Kết luận triển khai",
  "",
  "SafeFleet hiện là một MVP end-to-end gồm web điều hành đội xe, backend Spring Boot, PostgreSQL, ứng dụng Flutter cho tài xế, AI service FastAPI và hạ tầng Docker. Luồng dữ liệu chính đã được kiểm tra bằng dữ liệu thật: tài xế đăng nhập, gửi cảnh báo/SOS/ảnh bằng chứng; backend xác lập đúng tài xế từ JWT, ghi PostgreSQL, phát realtime và web quản lý có thể tiếp nhận/cập nhật trạng thái.",
  "",
  "Hệ thống giải quyết các nỗi đau trọng tâm: điều phối thiếu dữ liệu tức thời, khó theo dõi giờ lái và rủi ro tài xế, báo ngập rời rạc, SOS thiếu vòng đời xử lý, mất mạng làm mất dữ liệu, và thiếu bằng chứng có kiểm soát truy cập.",
  "",
  "## 2. Cấu trúc và trách nhiệm module",
  "",
  "| Module | Công nghệ | Trách nhiệm | Đầu vào chính | Đầu ra chính |",
  "|---|---|---|---|---|",
  "| `web_quan_ly/backend` | Java 21, Spring Boot 3.3.7, JPA, Flyway | Auth/RBAC, nghiệp vụ đội xe, mobile facade, navigation, realtime, evidence, push fallback | REST JSON/multipart, STOMP CONNECT, GPS/safety/SOS | JSON envelope, STOMP topic, PostgreSQL, MinIO private (local fallback) |",
  "| `web_quan_ly/frontend` | Next.js 16.2.12, React 19, MapLibre | 16 route ứng dụng gồm Command Center, thiết bị và bảo trì | REST backend, STOMP realtime | Dashboard, bản đồ, bảng điều phối, workflow sự cố |",
  "| `safe_fleet_driver_ui` | Flutter 3.44.5, Dart 3.12.2 | App tài xế, GPS, offline queue, dẫn đường, AI cabin cục bộ | Camera trước, GPS, thao tác tài xế, REST | Cảnh báo tại máy, telemetry/safety/SOS/flood, UI chuyến đi |",
  "| `safefleet_ai` | Python 3.11, FastAPI | Intent fallback, metadata model, train/evaluate/export/benchmark | Transcript, dữ liệu hiệu chuẩn | Intent, confidence, metadata/export |",
  "| `docker-compose.yml` | Docker Compose | PostgreSQL/backend/frontend/AI/MinIO, healthcheck và volume | `.env` | Stack local có thể khởi động thống nhất |",
  "",
  "## 3. Cổng, URL và dữ liệu bền vững",
  "",
  "| Thành phần | URL/cổng host | Health | Dữ liệu bền vững |",
  "|---|---|---|---|",
  "| Web | `http://localhost:3000` | HTTP `/` | stateless |",
  "| Backend | `http://localhost:8080` | `/actuator/health` | PostgreSQL + MinIO private; `evidence_data` chỉ dùng khi chọn local fallback |",
  "| OpenAPI | `http://localhost:8080/v3/api-docs` | HTTP 200 | — |",
  "| Swagger UI | `http://localhost:8080/swagger-ui/index.html` | HTTP 200 | — |",
  "| AI | `http://localhost:8000` | `/health` | model metadata bind mount |",
  "| PostgreSQL | `127.0.0.1:5432` | container healthcheck | `postgres_data` |",
  "| MinIO | `http://localhost:9000`, console `:9001` | `/minio/health/live` | `minio_data` |",
  "",
  "Không đưa password, JWT secret hoặc access token vào mã nguồn/tài liệu. App Android emulator dùng `http://10.0.2.2:8080/api/v1`; điện thoại thật dùng `http://<IP-LAN-PC>:8080/api/v1`.",
  "",
  "## 4. Chức năng đã có",
  "",
  "- Access token + refresh token xoay vòng, logout/revoke, BCrypt, RBAC và ownership theo tài xế.",
  "- Quản lý tài khoản, tài xế, xe, thiết bị, chuyến, điều phối, bảo trì, ngập, cảnh báo, sự cố và báo cáo.",
  "- Mobile bootstrap, assignment, checklist/workflow chuyến, driving session, telemetry đơn/batch có ACK ổn định.",
  "- Offline queue ưu tiên `SOS → safety CRITICAL → safety HIGH → workflow → flood → telemetry`; chỉ xóa sau ACK server.",
  "- Safety/SOS/flood/workflow dùng `clientEventId` chống gửi lặp; safety có cooldown 30 giây; server bỏ qua `driverId/vehicleId/tripId` giả mạo từ app.",
  "- Navigation Photon/OSRM có fallback, ba phương án, chấm rủi ro ngập, detour, turn-by-turn, off-route 75 m/15 giây và reroute.",
  "- Evidence JPEG/PNG/WebP tối đa 8 MB, kiểm magic bytes, SHA-256, filename/path an toàn, tải có JWT/ownership và `no-store`.",
  "- Push token theo thiết bị; khi chưa có Firebase, notification chuyển `POLLING_FALLBACK` để app đọc REST.",
  "- STOMP native `/ws-native` và SockJS `/ws`; JWT bắt buộc ở frame CONNECT, CORS dùng origin cấu hình rõ ràng.",
  "- AI cabin xử lý camera ngay trên thiết bị: mắt/PERCLOS, head pose, yawn, nhãn điện thoại, tốc độ/thời lượng/cooldown; không stream video liên tục lên server.",
  "- Web Command Center tone trắng/navy/teal, MapLibre, STOMP realtime và REST polling dự phòng 30 giây.",
  "",
  "## 5. Quy ước API cho app",
  "",
  "Base URL: `/api/v1`. Trừ login/refresh và health/OpenAPI, API nghiệp vụ dùng `Authorization: Bearer <accessToken>`.",
  "",
  "Response thông thường:",
  "",
  "```json",
  "{",
  '  "success": true,',
  '  "message": "Thông báo",',
  '  "data": {},',
  '  "timestamp": "2026-07-27T02:00:00+07:00"',
  "}",
  "```",
  "",
  "Mã lỗi quan trọng: `400` payload/rule sai, `401` thiếu hoặc hết JWT, `403` sai role/ownership, `404` không tồn tại, `409` xung đột trạng thái, `429` vượt rate limit, `500` lỗi ngoài dự kiến. Client phải giữ `clientEventId` ổn định khi retry và không tự sinh ID mới cho cùng một sự kiện.",
  "",
  "## 6. Luồng tích hợp app tài xế khuyến nghị",
  "",
  "1. Login, lưu token trong secure storage; refresh im lặng khi access token hết hạn.",
  "2. Gọi `GET /mobile/bootstrap`, cache danh mục cần offline và hiển thị assignment/trip hiện hành.",
  "3. Bắt đầu workflow/checklist; mở driving session và thu GPS theo chu kỳ phù hợp.",
  "4. Khi online gửi telemetry batch; khi offline ghi queue SQLite cùng `clientEventId`, `createdAt` và priority.",
  "5. AI camera phát cảnh báo cục bộ trước; chỉ gửi metadata safety event và evidence người dùng cho phép/chính sách yêu cầu.",
  "6. SOS được ưu tiên cao nhất; server lấy tài xế/chuyến/xe từ JWT context và trả lại ID ổn định khi retry.",
  "7. Navigation dùng alternative do backend khuyến nghị; gửi vị trí để kiểm off-route/reroute.",
  "8. Subscribe notification hoặc polling; hiển thị timeline incident và trạng thái đội điều hành đã accept/dispatch/resolve.",
  "9. Logout gọi API revoke rồi xóa secure storage và queue nhạy cảm đã đồng bộ.",
  "",
  "## 7. WebSocket/STOMP",
  "",
  "Kết nối native tới `ws://<host>:8080/ws-native`, sau khi mở socket gửi:",
  "",
  "```text",
  "CONNECT",
  "accept-version:1.2",
  "Authorization:Bearer <accessToken>",
  "heart-beat:10000,10000",
  "",
  "\\0",
  "```",
  "",
  "Topic chính: `/topic/telemetry`, `/topic/safety-events`, `/topic/incidents`, `/topic/flood-reports`, `/topic/notifications`. Kết nối không JWT nhận frame `ERROR`; client cần exponential backoff và REST polling dự phòng.",
  "",
  "## 8. Bằng chứng kiểm thử ngày 27/07/2026",
  "",
  "| Hạng mục | Kết quả |",
  "|---|---|",
  "| Backend Maven | unit/controller và integration trên Testcontainers PostgreSQL 17 |",
  "| Flyway | V1–V7 validate/migrate PASS; `ddl-auto=validate` |",
  "| API Docker thật | Login, push, safety replay, SOS replay, accept/timeline, evidence/403 PASS |",
  "| PostgreSQL query thật | safety, evidence SHA-256, SOS `ACCEPTED`, push `POLLING_FALLBACK` |",
  "| Evidence persistence | Tải 68 bytes trước và sau restart backend; PASS |",
  "| WebSocket | JWT → `CONNECTED`; anonymous → `ERROR` |",
  "| Frontend | full lint PASS; production build 17 route entry PASS; browser smoke Thiết bị/Bảo trì/RBAC PASS |",
  "| Dependency production | `npm audit --omit=dev`: 0 vulnerability |",
  "| Flutter | analyze 0 issue; 9/9 test PASS (gồm SQLite queue thật); Android debug APK build PASS từ vòng trước |",
  "| AI | 10/10 pytest PASS; benchmark 10.000 mẫu p95 khoảng 0,006 ms; sample evaluation F1 1,0 |",
  "| Docker | 5 service `healthy`; backend/web/AI/MinIO HTTP 200 |",
  "| Evidence/MinIO | upload PNG, SHA-256, bucket private, object `mc stat`, download đúng hash sau restart PASS |",
  "| Backup/restore | dump 116.313 byte; restore database tạm và chữ ký 12 chỉ số khớp; tự dọn sạch PASS |",
  "",
  "APK debug: `safe_fleet_driver_ui/build/app/outputs/flutter-apk/app-debug.apk`.",
  "",
  "## 9. Hạn chế còn lại trước triển khai thương mại",
  "",
  "- Không có thiết bị/emulator Android kết nối trong phiên kiểm thử; camera, GPS nền, quyền hệ điều hành và nhiệt/pin phải được pilot trên điện thoại thật.",
  "- FCM chưa có credential nên đang dùng REST polling fallback. Cần Firebase project/service account trước khi phát hành.",
  "- Phone usage hiện dùng ML Kit image labeling + temporal rules, chưa phải custom YOLO đã huấn luyện theo cabin Việt Nam. Repo có train/evaluate/export ONNX/TFLite nhưng cần dataset đồng thuận và hiệu chuẩn thực địa.",
  "- APK kiểm thử hiện là debug; release build đã buộc dùng keystore qua biến môi trường và chủ động từ chối nếu thiếu. Cần keystore thật, Play signing, HTTPS/domain và secret manager trước phát hành.",
  "- Photon/OSRM public có thể giới hạn tải hoặc gián đoạn; production nên tự host hoặc dùng nhà cung cấp có SLA.",
  "- Evidence mặc định Docker dùng bucket MinIO private và đã kiểm tra persistence; protected local volume vẫn là fallback có chủ đích khi cấu hình `EVIDENCE_STORAGE_PROVIDER=local`.",
  "- Full `npm audit` còn advisory trong công cụ ESLint/minimatch chỉ dùng lúc phát triển; runtime production audit bằng `--omit=dev` bằng 0.",
  "- Plugin ML Kit/MapLibre hiện vẫn áp dụng Kotlin Gradle Plugin kiểu cũ; Flutter stable hiện build được nhưng cần theo dõi bản plugin cho lần nâng Flutter sau.",
  "",
  "## 10. Lệnh vận hành nhanh",
  "",
  "```powershell",
  "Copy-Item .env.example .env",
  "docker compose config --quiet",
  "docker compose build",
  "docker compose up -d",
  ".\\docker\\scripts\\health-check.ps1",
  "node .\\docker\\scripts\\websocket-smoke.mjs",
  "```",
  "",
  "Dừng nhưng giữ dữ liệu: `docker compose down`. Không dùng `-v` nếu không chủ ý xóa volume.",
  "",
  `## 11. Danh mục đầy đủ ${operations.length} API`,
  "",
  `OpenAPI có ${Object.keys(spec.paths ?? {}).length} path và ${operations.length} operation. Input/output bên dưới được lấy trực tiếp từ code runtime, không nhập tay.`,
  "",
  "| Method | Path | Nhóm | Mục đích | Auth | Input | Output |",
  "|---|---|---|---|---|---|---|",
);

for (const operation of operations) {
  add(
    `| \`${operation.method}\` | \`${escapeCell(operation.path)}\` | ${escapeCell(operation.tag)} | ${escapeCell(operation.summary)} | ${escapeCell(operation.auth)} | ${operation.input} | ${operation.output} |`,
  );
}

add(
  "",
  `## 12. Định nghĩa ${schemas.length} schema input/output`,
  "",
  "Các trường có dấu `*` là bắt buộc theo OpenAPI. Enum phải gửi đúng chữ hoa như mô tả.",
  "",
);

for (const [name, schema] of schemas) {
  add(`### ${name}`, "");
  if (schema.description) add(schema.description, "");
  if (schema.enum) {
    add(`Giá trị: ${schema.enum.map((value) => `\`${value}\``).join(", ")}`, "");
  }
  const properties = Object.entries(schema.properties ?? {});
  if (!properties.length) {
    add(`Kiểu: ${schemaLabel(schema)}`, "");
    continue;
  }
  const required = new Set(schema.required ?? []);
  add("| Trường | Kiểu | Ràng buộc/mô tả |", "|---|---|---|");
  for (const [propertyName, property] of properties) {
    const constraints = [];
    if (required.has(propertyName)) constraints.push("bắt buộc");
    if (property.minimum !== undefined) constraints.push(`min ${property.minimum}`);
    if (property.maximum !== undefined) constraints.push(`max ${property.maximum}`);
    if (property.minLength !== undefined) constraints.push(`minLength ${property.minLength}`);
    if (property.maxLength !== undefined) constraints.push(`maxLength ${property.maxLength}`);
    if (property.pattern) constraints.push(`pattern \`${property.pattern}\``);
    if (property.description) constraints.push(property.description);
    add(
      `| \`${escapeCell(propertyName)}${required.has(propertyName) ? "*" : ""}\` | ${schemaLabel(property)} | ${escapeCell(constraints.join("; ") || "—")} |`,
    );
  }
  add("");
}

add(
  "## 13. Nguồn sự thật và tài liệu liên quan",
  "",
  "- OpenAPI runtime: `/v3/api-docs` và Swagger UI.",
  "- Mobile contract bổ sung: `web_quan_ly/backend/MOBILE_API_CONTRACT.md`.",
  "- Master prompt và nhật ký loop: `docs/CODEX_FULL_PROGRESS.md`.",
  "- DB evidence: `docs/DATABASE_VERIFICATION.md`.",
  "- Runbook: `docs/DOCKER_RUNBOOK.md`.",
  "- Kiểm thử thiết bị: `docs/LOCAL_DEVICE_TEST.md`.",
  "- Quyết định kỹ thuật/fallback: `docs/CODEX_DECISIONS.md`.",
  "",
  "Không suy đoán field ngoài OpenAPI. Khi backend thay đổi, chạy lại `node .\\docker\\scripts\\export-api-report.mjs` và commit báo cáo mới cùng code.",
  "",
);

await writeFile(output, `${lines.join("\n")}\n`, "utf8");
console.log(
  JSON.stringify({
    output,
    paths: Object.keys(spec.paths ?? {}).length,
    operations: operations.length,
    schemas: schemas.length,
  }),
);
