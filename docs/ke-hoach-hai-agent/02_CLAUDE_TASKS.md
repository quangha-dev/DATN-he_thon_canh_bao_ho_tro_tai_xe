# Task plan của Claude

Claude phụ trách web quản lý, ứng dụng Flutter, UX, client tests và nghiệm thu hành trình. Claude không tự tạo API mới hoặc sửa migration; mọi thiếu hụt contract được ghi vào handoff để Codex xử lý.

## W0 — Baseline và ánh xạ UI

| ID | P | Công việc | Phụ thuộc | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| CL-000 | P0 | Chốt baseline client | Baseline SHA từ C-000 | Chạy lại frontend lint/build, Flutter analyze/test và Android debug build; ghi bằng chứng; không sửa/xóa thay đổi chưa commit của người dùng |
| CL-001 | P0 | Inventory route/screen/UX gap | CL-000 | Ma trận màn hình → actor/role → API → loading/empty/error/offline; xác định component tái sử dụng; gửi yêu cầu contract cho C-001 |

## W1 — Session, notification và mobile release

| ID | P | Công việc | Phụ thuộc | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| CL-101 | P0 | Hardening session web | C-102 `CONTRACT_READY` | Loại access/refresh token khỏi `localStorage`; dùng BFF/HttpOnly cookie theo contract; xử lý refresh/logout/401/403; test XSS-sensitive storage, hết hạn và nhiều tab |
| CL-102 | P0 | Đồng bộ auth state Flutter | C-102 `CONTRACT_READY` | ApiClient báo SessionController khi refresh thất bại; restore session lúc mở app; điều hướng login đúng một lần; test token hết hạn, offline và refresh race |
| CL-103 | P0 | FCM client end-to-end | C-103 `CONTRACT_READY` | Permission UX; đăng ký/rotate/xóa token; foreground/background/terminated notification; deep link đúng chuyến; chống hiển thị trùng; checklist staging trên điện thoại thật |
| CL-104 | P0 | Android release | C-104 workflow contract | Signing config qua secret, release flavor, AAB, ProGuard/R8 nếu phù hợp, versioning; không commit keystore; cài thử bản release và smoke flow; iOS tách blocker nếu chưa có macOS/certificate |

## W2 — Hoàn thiện web quản lý và mobile

| ID | P | Công việc | Phụ thuộc | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| CL-201 | P1 | Quản lý thiết bị | C-201 `CONTRACT_READY` | Danh sách/filter/detail/create/edit; gán/bỏ gán; connection logs; loading/empty/error/RBAC; component và client tests |
| CL-202 | P1 | Replay và timeline chuyến | C-202 `CONTRACT_READY` | Bản đồ replay telemetry, scrub thời gian, event markers, timeline; xử lý chuyến không có/toạ độ lỗi/dữ liệu lớn; browser E2E |
| CL-203 | P1 | Trung tâm incident/alert | C-202 `CONTRACT_READY` | Assign dispatcher/rescue, thêm note timeline, dismiss alert, tạo/link incident; confirm hành động; realtime update; quyền và lỗi xung đột trạng thái |
| CL-204 | P1 | Kho và xác nhận nhận | C-203 `CONTRACT_READY` | Issue list/detail/filter và confirm receipt; trạng thái rõ; idempotent double-click; audit info hiển thị hợp lý |
| CL-205 | P1 | Bảo trì và hết hạn giấy tờ | C-203 `CONTRACT_READY` | Dashboard due/overdue, filter xe/tài xế/loại giấy tờ, detail/history và CTA nghiệp vụ; trạng thái cảnh báo nhất quán |
| CL-206 | P1 | Báo cáo quản lý | C-204 `CONTRACT_READY` | Lọc ngày/tháng/năm và timezone; KPI distance/driving minutes; breakdown tài xế/xe/ngập/sự cố; bảng/chart/export; đối soát một mẫu với API |
| CL-207 | P1 | Quản trị tài liệu RAG | C-205 `CONTRACT_READY` | Upload, validation errors, version history, preview chunk, approve/publish/retire; audit; ngăn publish tài liệu lỗi; UI phân biệt draft/active/retired |
| CL-208 | P1 | Timeline SOS cho tài xế | C-206 `CONTRACT_READY` | Hiển thị trạng thái/timeline đầy đủ, realtime/poll fallback, retry và offline state; chỉ hiển thị SOS của tài xế hiện tại; Flutter tests |
| CL-209 | P1 | Lịch sử sâu tài xế/phương tiện | C-204 và API hiện có | Trang detail thống nhất chuyến, cảnh báo, incident, bảo trì, giấy tờ và KPI theo kỳ; không tải toàn bộ dữ liệu một lần |

## W3 — Nghiệm thu thực địa

| ID | P | Công việc | Phụ thuộc | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| CL-301 | P1 | Pilot ngủ gật | Bản release CL-104 | Ma trận thiết bị/ánh sáng/kính/tư thế; lưu ground truth có đồng ý; confusion matrix, false alert/hour, latency và battery/thermal; không tuyên bố đạt chỉ từ unit test |
| CL-302 | P1 | Pilot routing 30–50 tuyến | C-301, CL-104 | Bộ tuyến đô thị/ngoại thành/mất mạng/lệch tuyến; arrival/reroute/ETA/fallback; log sai khác và issue tái hiện được |
| CL-303 | P1 | Full long-flow E2E | W2 verified | Quản lý tạo/giao chuyến → tài xế nhận → bắt đầu → telemetry/cảnh báo/SOS → kết thúc → report; thêm FCM, kho, incident, RAG; bằng chứng video/screenshot/log không chứa PII |
| CL-304 | P1 | Báo cáo nghiệm thu sản phẩm | CL-301…303 | Kết quả theo actor/thiết bị/trình duyệt, lỗi còn lại, mức `staging/field verified`; input cho C-305 |

## W4 — Có điều kiện

| ID | P | Công việc | Điều kiện kích hoạt | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| CL-401 | P2 | UX live traffic ETA/offline map | C-403 `CONTRACT_READY`; quyết định phạm vi offline map | Nguồn ETA được ghi rõ; degraded/offline UX; test mất mạng/provider timeout; không quảng bá live traffic khi đang dùng ETA tĩnh |
| CL-402 | P2 | UX xác nhận mutation agent | C-402 được duyệt | Preview tác động, confirm/cancel, hiển thị audit/result, chống submit lặp và phân quyền; không cho nhập/chạy SQL |

## Thứ tự thực hiện khuyến nghị

`CL-000 → CL-001 → CL-101 → CL-102 → CL-103 → CL-104 → CL-201…CL-209 → CL-301…CL-304`

Trong W2, ưu tiên từng vertical slice đã có contract hoàn chỉnh thay vì dựng toàn bộ UI bằng mock rồi tích hợp cuối kỳ.
