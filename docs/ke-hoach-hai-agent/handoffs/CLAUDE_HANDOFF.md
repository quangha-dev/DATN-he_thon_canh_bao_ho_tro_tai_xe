# Claude handoff log

Claude chỉ ghi kết quả task của mình trong file này. Giữ các mục mới nhất ở trên cùng và không xóa lịch sử.

## [CL-001] Inventory route/screen/UX gap — 2026-08-27 07:55

- Status: IN_PROGRESS
- Baseline SHA: `a595adb90656fcf37f99c2bcf1641ae5508848d9`
- Commit SHA: `626aa6429eb7ba0d55512db6dc1e9325336f9932`
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
- Commit SHA: `626aa6429eb7ba0d55512db6dc1e9325336f9932`
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
