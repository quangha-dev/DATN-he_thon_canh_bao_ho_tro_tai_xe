# Claude handoff log

Claude chỉ ghi kết quả task của mình trong file này. Giữ các mục mới nhất ở trên cùng và không xóa lịch sử.

## [INFRA] Thay Caddy bằng Nginx, sửa CI, chuẩn bị deploy VPS — 2026-08-27 10:45

- Status: REVIEW
- Baseline SHA: `a595adb90656fcf37f99c2bcf1641ae5508848d9`
- Commit SHA: `ea013c8` (hạ tầng), `fe61aa6` (sửa bản phát hành)
- Branch: `clients/system-completion`

### ĐỔI QUYỀN SỞ HỮU — cần Codex biết ngay

Người dùng đã quyết định **Claude tiếp quản hạ tầng**: `.github/**`, `deploy/**`,
`.gitignore` và `docker-compose*.yml`. Codex **dừng sửa** các file này để tránh
xung đột khi gộp nhánh. Quyết định này ghi đè mục 5 của `00_SHARED_CONTEXT.md`
cho tới khi người dùng nói khác.

Người dùng cũng chọn **Nginx thay Caddy** sau khi tôi nêu rằng Caddy đã chạy được
và tự lo chứng chỉ.

### Phạm vi đã làm

| File | Việc |
|---|---|
| `deploy/vps/nginx/nginx.conf` | rate limit theo IP, log JSON có `request_time`, gzip, giới hạn body 16 MB theo `EVIDENCE_MAX_SIZE_BYTES`/`OCR_MAX_UPLOAD_BYTES` |
| `deploy/vps/nginx/templates/safefleet.conf.template` | HTTP→HTTPS, webroot ACME, `/healthz`, TLS 1.2/1.3, HSTS, chặn `/actuator` và `/swagger-ui`, WebSocket `/ws-native` timeout 1 giờ, hạn mức riêng cho `/api/v1/auth/login` |
| `deploy/vps/init-tls.sh` | phát hành chứng chỉ lần đầu, kiểm tra DNS trước để không đốt hạn mức Let's Encrypt |
| `deploy/vps/docker-compose.vps.yml` | `caddy` → `nginx` + `certbot`; nginx tự nạp lại mỗi 6 giờ, không cần gắn `docker.sock` |
| `deploy/vps/deploy.sh` | chặn sớm khi chưa có chứng chỉ; `nginx -s reload` sau khi stack lên |
| `deploy/vps/health-check.sh` | kiểm tra định tuyến `/ws-native` và số ngày còn lại của chứng chỉ |
| `deploy/vps/RUNBOOK.md` | quy trình triển khai đầy đủ, mới |
| `.gitignore` | mở ngoại lệ cho `deploy/vps/.env.production.example` |
| `.github/workflows/ci-cd.yml` | job `mobile-release`; cổng checksum model; validate `nginx.conf` bằng chính image production |
| `android/app/build.gradle.kts` | sửa tên biến trong thông báo lỗi |

### Lệnh test và kết quả

| Kiểm tra | Kết quả |
|---|---|
| `nginx -t` trong `nginx:1.29-alpine`, chứng chỉ trong volume | **pass**; chỉ cảnh báo `ssl_stapling ignored` do cert tự ký, sẽ hết khi có cert thật |
| `docker compose config` 4 file chồng nhau | **pass** |
| `bash -n` cho 4 script deploy | **pass** |
| YAML workflow parse | **pass**, 8 job |
| envsubst giữ nguyên biến nginx | **pass** — `APP_DOMAIN` được thay, `$host`/`$remote_addr` còn nguyên nhờ `NGINX_ENVSUBST_FILTER=^APP_` |
| sha256 model vs metadata | **khớp** ở cả baseline lẫn worktree chính, nên cổng CI mới sẽ pass |

### BLOCKER-CI-1 đã xử lý

`deploy/vps/.env.production.example` bị `.gitignore` dòng 3 (`.env.*`) nuốt nên
không có trong bất kỳ checkout nào của CI, làm job `compose-validate` chết ngay
bước đầu. Đã thêm ngoại lệ và commit file (chỉ chứa placeholder).

### Phát hiện mới khi build bản phát hành

`flutter build apk --release` **thất bại có chủ đích**: `build.gradle.kts` ném
`GradleException` với mọi task chứa chữ "release" nếu thiếu bốn biến
`SAFEEFLEET_ANDROID_*`. Đây là thiết kế tốt, nhưng kéo theo hai việc:

1. Thông báo lỗi ghi sai tên biến (`SAFEFLEET_` thay vì `SAFEEFLEET_`) — đã sửa.
2. Job `mobile-release` sẽ fail chắc chắn khi chưa có secret keystore — đã gắn
   điều kiện theo `ANDROID_KEYSTORE_BASE64` và in notice thay vì để job đỏ.

Chưa có keystore nên bản giao cho người dùng lần này là **APK debug** tách theo
ABI, trỏ về `https://safefleet.duckdns.org/api/v1`.

### Rủi ro/blocker còn lại

- **DNS chưa trỏ đúng.** `safefleet.duckdns.org` đang trỏ `1.55.171.51`, không
  phải `169.58.207.226`. Không sửa thì `init-tls.sh` sẽ dừng ở bước kiểm tra DNS.
- **Chưa deploy thật.** Tôi không nhận mật khẩu root, nên việc chạy trên VPS do
  người dùng thực hiện theo `RUNBOOK.md`. Mọi kết luận vẫn ở mức `code-ready`.
- **CSP đang ở Report-Only.** Cần soi báo cáo vi phạm rồi mới chuyển sang chặn.
- **Sao lưu vẫn nằm trên cùng VPS**; chưa có bản off-site và chưa diễn tập khôi phục.
- BLOCKER-CL000-1 (model ngủ gật trong baseline là bản cũ) **vẫn mở**.

### Task phía agent kia có thể bắt đầu

- Codex: dừng sửa `.github/**` và `deploy/**`. C-001 vẫn chờ; input contract cho
  CL-201/204/207 đã có trong mục CL-001 bên dưới.

## [RÀ SOÁT] Trạng thái CI/CD và self-hosted runner — 2026-08-27 08:10

- Status: REVIEW (chỉ rà soát, không sửa — `.github/**` và `deploy/**` thuộc Codex)
- Baseline SHA: `a595adb90656fcf37f99c2bcf1641ae5508848d9`
- Phạm vi: trả lời câu hỏi của người dùng "đã cấu hình CI/CD chưa và self-hosted runner chưa".

### Kết luận

1. **CI/CD có file, chưa từng chạy.** `.github/workflows/ci-cd.yml` (8.205 byte, 7 job) nằm trong baseline commit. Nhưng `git ls-remote --heads origin` cho thấy GitHub chỉ có đúng một nhánh `main` tại `f380cd0` (18/08/2026), và `git ls-tree -r origin/main` **không có `.github/` lẫn `deploy/`**. Baseline local đã tách nhánh khỏi `origin/main` và đi trước 10 commit. Chưa có một lần workflow run nào.
2. **Không có self-hosted runner.** Cả 7 job đều `runs-on: ubuntu-latest`; grep `self-hosted` = 0 kết quả. Máy phát triển hiện tại không có service `actions.runner.*`, không có tiến trình `Runner.Listener`/`Runner.Worker`, không có thư mục `actions-runner*` ở gốc `C:\` hay `D:\`. Mô hình deploy là push-based: runner GitHub-hosted SSH vào VPS, không phải runner đặt trên VPS.

### BLOCKER-CI-1 — `compose-validate` sẽ fail ngay lần chạy đầu tiên

Job `compose-validate` bắt đầu bằng `cp deploy/vps/.env.production.example .env.validation`. File đó **có trên đĩa nhưng không có trong Git**:

```
git check-ignore -v deploy/vps/.env.production.example
=> .gitignore:3:.env.*   deploy/vps/.env.production.example
```

`.gitignore` dòng 3 `.env.*` nuốt file này; dòng 4 `!.env.example` chỉ cứu được `.env.example` ở gốc, không cứu `deploy/vps/.env.production.example`. Mọi checkout của CI đều thiếu file ⇒ job fail ở bước đầu, kéo theo `publish-images` và `deploy-production` không bao giờ chạy.

Đề xuất (Codex thực hiện): thêm ngoại lệ `!deploy/vps/.env.production.example` vào `.gitignore` rồi commit file, sau khi xác nhận nội dung chỉ chứa placeholder.

### Khoảng trống trong vùng Claude (job `mobile-test`)

Job hiện chỉ có `flutter pub get` → `analyze` → `test` → `build apk --debug`. Ba thiếu sót liên quan trực tiếp tới task của tôi:

| Thiếu | Ảnh hưởng |
|---|---|
| Không có build release/AAB/signing | CL-104 chưa có gì trong CI; không đo được kích thước artifact phát hành (xem quan sát APK debug 601 MB ở CL-000) |
| Không có cổng checksum model | Đúng BLOCKER-CL000-2: CI sẽ build và publish với model ngủ gật sai mà không cảnh báo |
| `integration_test/` không chạy | `stgt_tflite_model_test.dart` là thứ duy nhất chạm `.tflite` thật, cần thiết bị/emulator nên không có trong CI |

Tôi sẽ đề xuất bước CI cụ thể cho `mobile-test` khi làm CL-104; không tự sửa `.github/**`.

### Secret/feature flag cần cấu hình

Workflow yêu cầu 10 secret + 1 variable, chưa có bằng chứng đã cấu hình trên GitHub Environment `production`:
`GHCR_USERNAME`, `GHCR_READ_TOKEN`, `OCR_MODELS_ARCHIVE_URL`, `OCR_MODELS_ARCHIVE_SHA`, `OCR_MODELS_DOWNLOAD_TOKEN`, `VPS_HOST`, `VPS_USER`, `VPS_SSH_PRIVATE_KEY`, `VPS_KNOWN_HOSTS`, `GITHUB_TOKEN` (mặc định), và `vars.APP_DOMAIN`.

### Điểm làm tốt cần giữ

Mọi `uses:` đều ghim theo commit SHA thay vì tag — chống được supply-chain attack qua tag bị dời. Deploy có `concurrency` group và `cancel-in-progress: false`, tránh hai lần deploy chồng nhau.

### Task phía agent kia có thể bắt đầu

- Codex: xử lý BLOCKER-CI-1; quyết định thời điểm push `.github/` + `deploy/` lên GitHub và cấu hình Environment/secret; xác nhận có dùng self-hosted runner hay giữ GitHub-hosted.

## [CL-001] Inventory route/screen/UX gap — 2026-08-27 07:55

- Status: IN_PROGRESS
- Baseline SHA: `a595adb90656fcf37f99c2bcf1641ae5508848d9`
- Commit SHA: `7b9bc0e48970429b4e392d85d996837c4bdbce93`
- Phạm vi đã làm: kiểm chứng bằng mã nguồn (không dựa vào báo cáo rà soát) 4 khoảng trống W2 để C-001 có input cụ thể. Ma trận đầy đủ 20 route sẽ bổ sung ở lượt sau.
- API/migration/config thay đổi: không.
- File chính đã đổi: chỉ file handoff này.

### Khoảng trống đã kiểm chứng bằng mã nguồn

| Task | Bằng chứng trong repo tại baseline | Kết luận |
|---|---|---|
| CL-201 Thiết bị | `lib/safeFleetApi.ts:1050` chỉ có `getData("/devices", …)`; grep `createDevice\|updateDevice\|deleteDevice\|assignDevice\|connectionLog` trong `app/(dashboard)/devices/page.tsx` và `lib/safeFleetApi.ts` = 0 kết quả; nút "Gắn thiết bị" (`devices/page.tsx:174`) chỉ gọi `showToast(...)` chuyển hướng sang mục Phương tiện | Web chỉ đọc danh sách. Thiếu toàn bộ CRUD, gán/bỏ gán và connection log |
| CL-204 Kho | Không có route `warehouse`; `warehouseIssue*` chỉ xuất hiện như input nhúng trong `app/(dashboard)/dispatch/page.tsx` khi tạo lệnh điều phối | Chưa có trang danh sách/chi tiết phiếu và thao tác xác nhận nhận hàng |
| CL-207 Tài liệu RAG | 18 route `page.tsx`, không có route quản trị tài liệu RAG. `/document-reviews` là soát OCR phiếu nhật trình, khác nghiệp vụ | Thiếu hoàn toàn màn quản trị corpus |
| CL-202/203/205/206/209 | `/trips`, `/incidents`, `/alerts`, `/maintenance`, `/reports`, `/drivers`, `/vehicles` đều tồn tại | Là bài toán bổ sung năng lực trên route sẵn có, không phải dựng route mới |

### Yêu cầu contract gửi C-001

Mô tả use case và trạng thái UI cần dữ liệu; không phát minh endpoint hay tên field.

**CL-201 Quản lý thiết bị.** Cần contract cho: liệt kê có phân trang + filter theo trạng thái/loại/xe; xem chi tiết; tạo/sửa/ngừng dùng; gán và bỏ gán thiết bị khỏi phương tiện; đọc connection log theo thiết bị có phân trang thời gian. Trạng thái UI cần dữ liệu: loading; rỗng (chưa có thiết bị nào / chưa từng kết nối); lỗi mạng; 403 khi vai trò con không đủ quyền; xung đột khi gán thiết bị đã thuộc xe khác. Cần biết: mã lỗi phân biệt "đã gán cho xe khác" với "thiết bị không tồn tại", và thao tác gán có idempotency key không.

**CL-204 Phiếu xuất kho.** Cần contract cho: danh sách phiếu có filter kỳ/trạng thái/xe/tài xế; chi tiết phiếu kèm dòng hàng; xác nhận nhận hàng. Trạng thái UI: loading; rỗng; lỗi; 403; và quan trọng nhất là **double-click xác nhận** — cần biết cơ chế idempotency và mã lỗi khi phiếu đã được xác nhận trước đó, để UI không hiển thị sai thành lỗi hệ thống.

**CL-207 Quản trị tài liệu RAG.** Cần contract cho: upload tài liệu; danh sách theo trạng thái draft/active/retired; lịch sử phiên bản; xem trước chunk đã tách; approve/publish/retire. Trạng thái UI: đang xử lý tách chunk; lỗi validation từng file (định dạng, kích thước, không trích được văn bản); lỗi; 403. Cần biết: publish là đồng bộ hay bất đồng bộ (quyết định UI có cần polling không), và trường nguồn/phiên bản/ngày hiệu lực theo mục 6.11 của `00_SHARED_CONTEXT.md`.

Tôi ACK contract khi Codex công bố; không tự đặt tên field hay endpoint thay thế.

## [CL-000] Chốt baseline client — 2026-08-27 07:55

- Status: REVIEW
- Baseline SHA: `a595adb90656fcf37f99c2bcf1641ae5508848d9`
- Branch/worktree: `clients/system-completion` tại `D:\DEV\Project\DATN\DATN-safe-fleet-clients`
- Commit SHA: `7b9bc0e48970429b4e392d85d996837c4bdbce93`
- Phạm vi đã làm: tạo worktree client riêng từ đúng baseline SHA; chạy lại toàn bộ cổng G0 phía client; không sửa/xóa bất kỳ thay đổi chưa commit nào của người dùng.
- API/migration/config thay đổi: không. Không chạm backend, migration, Compose hay CI.
- File chính đã đổi: chỉ `docs/ke-hoach-hai-agent/handoffs/CLAUDE_HANDOFF.md`.

### Lệnh test và kết quả

Chạy trên worktree baseline thuần `DATN-safe-fleet-clients` (`a595adb`):

| Cổng | Lệnh | Kết quả |
|---|---|---|
| Flutter analyze | `flutter analyze` | **No issues found** (61,5 s) |
| Flutter test | `flutter test` | **114 pass, 3 skip** (3 skip là preview render, opt-in qua `SF_RENDER_PREVIEW`) |
| Drowsiness/temporal | `flutter test test/stgt_drowsiness_engine_test.dart test/temporal_safety_engine_test.dart` | **11 pass** |

Chạy trên worktree chính `DATN-he_thon_canh_bao_ho_tro_tai_xe`, nơi nội dung `web_quan_ly/frontend/**` **giống hệt baseline** (`git status --porcelain` không liệt kê file frontend nào):

| Cổng | Lệnh | Kết quả |
|---|---|---|
| Frontend lint | `npm run lint` | **pass**, không cảnh báo |
| Frontend build | `npm run build` | **pass**, Compiled successfully 7,7 s, sinh **20 route** |
| Android debug | `flutter build apk --debug` | **pass**, `build/app/outputs/flutter-apk/app-debug.apk` |

Lưu ý về Android debug: build này chạy ở worktree chính, tức có 2 file model đang sửa cục bộ. Chưa build lại APK ở worktree baseline thuần để tiết kiệm đĩa; sẽ build ở CL-104 khi làm release.

### Cách kiểm tra thủ công

```
git rev-parse HEAD                     # a595adb…
git worktree list                      # 3 worktree, không trùng thư mục
git status --porcelain                 # 3 M + 8 ?? , đều ngoài vùng Claude sửa
```

### Secret/feature flag cần cấu hình

Không thêm secret. Không commit credential, keystore hay PII.

### Rủi ro/blocker/công việc còn lại

**BLOCKER-CL000-1 — Model ngủ gật trong baseline không khớp model đang dùng.**

Baseline commit *có* chứa `assets/models/drowsiness_model.{json,tflite}`, nhưng đó là **phiên bản cũ**. Bản đang dùng ở worktree chính bị giữ ngoài commit theo chủ ý của Codex (metadata chứa đường dẫn máy cục bộ `D:/DEV/Project/course/ngugat/...`).

| Trường | Trong baseline commit | Trong worktree chính |
|---|---|---|
| `input_shape` | `[1, 1, 75, 12]` | `[1, 75, 12]` |
| `calibration_frames` | `1500` | `75` |
| `runtime_sha256` | `FCC98759…` | `FFCCE4CE…` |

Hệ quả: **mọi bản build sinh ra từ baseline sẽ đóng gói model cũ.** Đây là rủi ro trực tiếp cho CL-104 và CL-301.

**BLOCKER-CL000-2 — Không có test nào phát hiện được sai model.**

- `grep -rn "drowsiness_model.json\|runtime_sha256\|input_shape" lib/ test/` = **0 kết quả**. Metadata model hiện chỉ là tài liệu, không có mã nào đối chiếu.
- Model thật chỉ được nạp ở `lib/core/ai/stgt_drowsiness_engine.dart:92` qua `Interpreter.fromAsset`.
- Bộ test đơn vị không chạm `.tflite`; chỉ `integration_test/stgt_tflite_model_test.dart` chạm, mà file này cần thiết bị/emulator và **chưa có bằng chứng đã chạy**.

Bằng chứng: 11 test ngủ gật **pass với cả hai phiên bản model**. Nghĩa là cổng test hiện tại không thể chặn việc ship nhầm model cho một tính năng an toàn.

Đề xuất gửi Codex/Integration Lead (tôi không tự sửa vì chạm chính sách artifact và CI):

1. Quyết định nguồn sự thật cho model: đưa model đã sửa vào baseline sau khi bỏ đường dẫn máy cục bộ khỏi metadata, **hoặc** đưa model ra artifact store có version + checksum và fail-fast khi thiếu.
2. Thêm cổng CI kiểm tra `sha256(drowsiness_model.tflite)` khớp `runtime_sha256` trong metadata.
3. Phía tôi sẽ bổ sung ở CL-301 một test đọc metadata và đối chiếu `input_shape` với hình dạng tensor engine yêu cầu, để sai lệch bị bắt ở `flutter test` chứ không phải ngoài đường.

**Quan sát cho CL-104 —** APK debug nặng **601 MB** trong khi `assets/` chỉ 2,3 MB; phần lớn đến từ native libs (ONNX Runtime, TFLite, ML Kit) của mọi ABI ở chế độ debug. Chưa phải lỗi, nhưng cần đo kích thước AAB release có tách ABI sớm ở CL-104 thay vì đợi lúc phát hành.

**Chưa xác minh:** mọi kết luận ở mức `code-ready` trên máy local. Chưa có `staging-verified`, `field-verified` hay `production-verified`.

### Task phía agent kia có thể bắt đầu

- C-001: đã có input CL-001 cho 3 slice CL-201 / CL-204 / CL-207 ở mục trên.
- Cần Codex/Integration Lead quyết định BLOCKER-CL000-1 trước khi tôi bắt đầu CL-104 hoặc CL-301.

## Chưa bắt đầu

- Baseline SHA: chưa chốt
- Task kế tiếp: CL-000
- Blocker: cần người dùng/Integration Lead xác nhận baseline commit trước khi hai agent code trên worktree riêng.
