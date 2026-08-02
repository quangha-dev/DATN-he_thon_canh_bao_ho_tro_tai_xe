# FRONTEND PROGRESS - SafeFleet Command Center

## 1. Trạng thái tổng quan
- Trạng thái hiện tại: Đã kết nối backend thật và pass kiểm thử build/lint/API contract
- Phase hiện tại: Integration & Frontend QA
- Màn hình đang làm: —
- Component đang làm: —
- Vấn đề đang gặp: Không
- Việc cần làm tiếp theo: Bổ sung E2E trình duyệt ổn định và kiểm thử thiết bị thật cho luồng realtime

## 2. Checklist tổng thể
- [x] Khởi tạo project (Next.js 15, TS, Tailwind v4)
- [x] Cấu hình Tailwind (Thêm design tokens, keyframes, custom animations)
- [x] Cấu hình routing (Auth routes & Protected Dashboard routes)
- [x] Tạo layout chính (AppLayout tích hợp Sidebar/Header)
- [x] Tạo sidebar (Thu gọn/mở rộng, phân nhóm, dark mode toggle)
- [x] Tạo header (Tên màn hình, ngày giờ, user avatar dropdown)
- [x] Tạo command search (Tìm kiếm nhanh Spotlight-style)
- [x] Tạo dashboard command center (Thống kê, Priority Panel, Chuyến đang chạy)
- [x] Tạo realtime map (MapLibre GL, vehicle markers, detail sliding drawer)
- [x] Tạo dispatch trip (Điều phối chuyến form + map + đề xuất AI)
- [x] Tạo vehicle management (Danh sách xe table/card, chi tiết xe tabs)
- [x] Tạo driver management (Danh sách tài xế, safety score, chi tiết tài xế)
- [x] Tạo AI alert center (Alert Feed + Alert Detail panel)
- [x] Tạo incident room (Phòng cứu hộ SOS khẩn cấp + Timeline xử lý)
- [x] Tạo flood map (Bản đồ điểm ngập lụt + Drawer chi tiết tác động)
- [x] Tạo reports (Fleet Intelligence + AI Insights + Recharts biểu đồ)
- [x] Tạo accounts (Quản lý tài khoản CRUD)
- [x] Tạo settings (Quy định thời gian lái xe tối đa + Server config)
- [x] Tạo device management (thiết bị, trạng thái kết nối, xe gắn thiết bị)
- [x] Tạo maintenance management (lệnh bảo trì, ưu tiên, chi phí, trạng thái)
- [x] Kết nối REST API thật từ Spring Boot backend
- [x] Cấu hình `.env.local` dùng `NEXT_PUBLIC_API_URL=http://localhost:8080/api/v1`
- [x] Đồng bộ Auth/JWT/RBAC với backend
- [x] Chặn route/menu theo role frontend
- [x] Chuẩn hóa lỗi mềm khi 401/403/login sai
- [x] Build và lint frontend sau tích hợp
- [x] WebSocket/STOMP realtime có reconnect và REST polling fallback

## 3. Log tiến độ
- 2026-07-08 01:15: Khởi tạo Next.js, cài đặt các packages (axios, recharts, framer-motion, lucide-react, maplibre-gl).
- 2026-07-08 01:20: Tạo design tokens & cấu hình theme Tailwind v4 tại `globals.css` và `layout.tsx`.
- 2026-07-08 01:22: Tạo các model TypeScript tại `types/index.ts`, apiClient tại `lib/apiClient.ts` và utils tại `lib/utils.ts`.
- 2026-07-08 01:24: Tạo mock data toàn bộ thực thể tại `data/mockData.ts` (bối cảnh Hà Nội).
- 2026-07-08 01:25: Tạo AuthContext (hỗ trợ login/logout, route guard, demo accounts) và ToastContext.
- 2026-07-08 01:27: Tạo AppLayout (`app/(dashboard)/layout.tsx`), Sidebar, Header.
- 2026-07-08 01:30: Thiết kế giao diện Login cao cấp và Command Center dashboard. Build dự án thành công.
- 2026-07-08 01:33: Tích hợp CommandSearch (Spotlight Search Ctrl+K) vào Header.
- 2026-07-08 01:35: Tạo MapView component tích hợp MapLibre GL và custom markers, hoàn thiện màn hình Bản đồ Realtime (Full-screen map, floating search/filters, collapsible left list panel và right drawer).
- 2026-07-08 01:37: Hoàn thiện các trang danh sách xe (Vehicle Management) và tài xế (Driver Management). Build dự án thành công không lỗi TS.
- 2026-07-08 01:40: Hoàn thiện trang Điều phối chuyến (Dispatch Workspace) phối hợp Form và Map có AI đề xuất.
- 2026-07-08 01:42: Hoàn thiện trang Quản lý chuyến đi (Trips) với các card thống kê và bảng dữ liệu.
- 2026-07-08 01:44: Thiết kế trung tâm quản lý Cảnh báo AI (AI Alert Center) dạng Split-layout Timeline Alert Feed và Alert Detail.
- 2026-07-08 01:46: Thiết kế phòng xử lý sự cố khẩn cấp (Incident Room) gồm timeline theo dõi cứu hộ và định vị sự cố.
- 2026-07-08 01:48: Thiết kế bản đồ ngập lụt thông minh (Flood Map) tích hợp MapLibre GL, bộ lọc mức độ ngập và drawer chi tiết tác động.
- 2026-07-08 01:50: Thiết kế trang Báo cáo (Fleet Intelligence) tích hợp biểu đồ Recharts và AI Insight box.
- 2026-07-08 01:52: Thiết kế trang quản lý tài khoản người dùng hệ thống (Accounts CRUD).
- 2026-07-08 01:54: Thiết kế trang Cấu hình hệ thống (Settings). Build dự án thành công toàn diện không lỗi biên dịch.
- 2026-07-08 04:20: Thêm `lib/safeFleetApi.ts` làm adapter giữa response backend và model UI; chuyển các trang dashboard, vehicle, driver, trip, alert, incident, flood, dispatch, account, setting, report sang dữ liệu thật.
- 2026-07-08 04:35: Cập nhật AuthContext login thật qua `/auth/login`, restore session qua `/auth/me`, lưu JWT vào `localStorage`, và đổi seed login thành `admin / 123456`.
- 2026-07-08 04:45: Sửa CORS backend cho `http://localhost:*` và `http://127.0.0.1:*`, xác nhận frontend dev server port 3001 gọi được backend 8080.
- 2026-07-08 05:05: Thêm `lib/accessControl.ts`, lọc sidebar/menu theo role, chặn route bằng thông báo mềm “Không có quyền truy cập”, và redirect default theo role.
- 2026-07-08 05:15: Sửa CommandSearch dùng `Promise.allSettled` để một API bị 403 không làm hỏng toàn bộ tìm kiếm; chỉ gọi nhóm dữ liệu mà role hiện tại có quyền xem.
- 2026-07-08 05:18: Bổ sung tìm kiếm sự cố/SOS trong CommandSearch để role `RESCUE_TEAM` vẫn có kết quả tìm kiếm phù hợp với màn hình được phép truy cập.
- 2026-07-08 05:20: Sửa logo SafeFleet về màn hình mặc định theo role (`DRIVER -> /trips`, `RESCUE_TEAM -> /incidents`, role quản trị -> `/command-center`).
- 2026-07-08 05:25: Kiểm thử: `npm.cmd run lint` pass, `npm.cmd run build` pass; backend CORS preflight 200; API RBAC thật: admin vào accounts 200, driver/rescue vào accounts 403 với message “Không có quyền truy cập”, driver vào trips 200.
- 2026-07-08 09:40: Sửa lỗi React duplicate key ở Command Center priority list bằng key ghép `type-id`.
- 2026-07-08 09:40: Nâng cấp Dispatch: autocomplete điểm đi/đến qua backend location API, bắt buộc chọn gợi ý có tọa độ, validate thời gian đi/đến, hiển thị tổng km/ETA, vẽ route preview trên MapLibre.
- 2026-07-08 09:40: Test frontend sau chỉnh dispatch: `npm.cmd run lint` pass, `npm.cmd run build` pass.
- 2026-07-27: Bổ sung `/devices` và `/maintenance`, nối REST API thật, đồng bộ menu/RBAC; ESLint các file thay đổi PASS và Next.js production build PASS với 17 route entry (16 route app + `_not-found`).

## 4. File đã tạo/sửa
- `app/globals.css`, `app/layout.tsx`, `app/page.tsx`
- `app/ClientProviders.tsx`
- `types/index.ts`
- `lib/apiClient.ts`, `lib/utils.ts`
- `lib/safeFleetApi.ts`, `lib/accessControl.ts`
- `.env.local`
- `data/mockData.ts`
- `context/AuthContext.tsx`, `context/ToastContext.tsx`
- `app/login/page.tsx`
- `components/layout/Sidebar.tsx`, `components/layout/Header.tsx`, `components/layout/CommandSearch.tsx`
- `components/map/MapView.tsx`
- `app/(dashboard)/layout.tsx`
- `app/(dashboard)/command-center/page.tsx`
- `app/(dashboard)/realtime-map/page.tsx`
- `app/(dashboard)/vehicles/page.tsx`
- `app/(dashboard)/drivers/page.tsx`
- `app/(dashboard)/dispatch/page.tsx`
- `app/(dashboard)/trips/page.tsx`
- `app/(dashboard)/alerts/page.tsx`
- `app/(dashboard)/incidents/page.tsx`
- `app/(dashboard)/flood-map/page.tsx`
- `app/(dashboard)/reports/page.tsx`
- `app/(dashboard)/accounts/page.tsx`
- `app/(dashboard)/settings/page.tsx`
- `app/(dashboard)/devices/page.tsx`
- `app/(dashboard)/maintenance/page.tsx`

## 5. Việc cần làm tiếp theo
- Bổ sung test E2E ổn định bằng Playwright package riêng nếu cần chạy kiểm thử trình duyệt tự động dài hơn.
- Pilot các luồng WebSocket/polling trên mạng LAN và trình duyệt mục tiêu.
