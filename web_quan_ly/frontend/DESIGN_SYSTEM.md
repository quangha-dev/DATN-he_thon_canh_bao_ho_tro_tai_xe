# SafeFleet — Design System

Tài liệu tham chiếu cho giao diện web quản lý sau đợt tái cấu trúc.
Toàn bộ logic gọi API giữ nguyên; chỉ lớp trình bày được thiết kế lại.

## 0. Phong cách thị giác

Bảng điều khiển kiểu SaaS mềm: nền xám rất nhạt, thẻ trắng bo góc rộng
(`--sf-r-lg` = 20px), tách nhau bằng bóng khuếch tán thay vì viền đậm, không
dùng hoạ tiết lưới hay gradient trang trí.

Quy tắc điểm nhấn: mỗi màn hình có **đúng một** thẻ tô đặc màu thương hiệu
(`<Card filled>` hoặc `<StatCard filled>`), phần còn lại là thẻ trắng. Màu chỉ
xuất hiện thêm ở ô icon (nền teal nhạt), badge và chấm trạng thái.

Chữ tối thiểu 12px, các mức màu chữ đều đạt WCAG AA để dễ đọc với người mắt kém.

---

## 1. Nguyên tắc màu (bắt buộc)

Mỗi trang chỉ được dùng **2 màu có sắc độ** cộng dải trung tính:

| Vai trò | Màu | Token | Dùng cho |
|---|---|---|---|
| Primary | Teal | `--sf-primary` | Nút chính, chỉ mục đang chọn, biểu đồ, marker xe đang chạy |
| Accent | Amber | `--sf-accent` | Nhấn mạnh phụ, badge cảnh báo AI, nút hành động thứ cấp |
| Neutral | Ink (xanh lạnh) | `--sf-ink-*` | Nền, chữ, viền, bóng đổ |

**Màu semantic** (`--sf-success` / `--sf-warning` / `--sf-danger` / `--sf-info`)
**chỉ** được dùng cho tín hiệu trạng thái kích thước nhỏ: chấm, badge, viền trái
3px, icon. Không dùng làm nền lớn, không dùng làm màu nút chính.

Sai: một trang có nút xanh dương + badge tím + card cam.
Đúng: một trang teal + amber, còn lại là ink; trạng thái thể hiện bằng chấm màu.

### Cách lấy màu trạng thái

Không viết màu thủ công. Dùng:

```tsx
import { toneOf, StatusLabel, Badge } from "@/components/ui";

<StatusLabel status={vehicle.status} label={VEHICLE_STATUS_LABELS[vehicle.status]} />
<Badge tone={toneOf(alert.severity)}>{SEVERITY_VI[alert.severity]}</Badge>
```

Bảng ánh xạ nằm ở `STATUS_TONE` trong `components/ui/primitives.tsx` — đây là
nguồn chân lý duy nhất cho màu trạng thái.

---

## 2. Token

Toàn bộ token nằm ở `app/globals.css`, khai báo hai lần: `:root` (sáng) và
`.dark` (tối). Mọi component đọc qua CSS variable nên **không cần viết
`dark:` variant** — đổi theme là màu tự đổi.

Nhóm token:

- Màu: `--sf-primary-*`, `--sf-accent-*`, `--sf-ink-*`, semantic
- Bề mặt: `--sf-bg`, `--sf-bg-card`, `--sf-bg-inset`, `--sf-bg-header`
- Chữ: `--sf-text`, `--sf-text-secondary`, `--sf-text-muted`
- Viền: `--sf-border`, `--sf-border-strong`, `--sf-border-light`
- Bóng: `--sf-shadow-xs` → `--sf-shadow-xl`, `--sf-glow-primary`
- Bo góc: `--sf-r-xs` (6px) → `--sf-r-xl` (24px), `--sf-r-pill`
- Chuyển động: `--sf-ease-out`, `--sf-ease-spring`, `--sf-dur-fast|base|slow`

Cầu nối sang Tailwind ở khối `@theme inline`, ví dụ `text-sf-text`,
`bg-sf-bg-card`, `border-sf-border`.

---

## 3. Lớp tiện ích

| Lớp | Công dụng |
|---|---|
| `.sf-app-shell` | Nền toàn trang, phẳng, không hoạ tiết |
| `.sf-surface` | Thẻ chuẩn: nền trắng, bo 20px, hairline rất nhạt, bóng mềm |
| `.sf-surface-filled` | Thẻ tô đặc màu thương hiệu — điểm nhấn duy nhất mỗi màn hình |
| `.sf-interactive` | Nâng 3px + đổ bóng khi rê chuột |
| `.sf-icon-chip` | Ô icon bo tròn nền teal nhạt, đặt ở góc thẻ |
| `.sf-inset` | Khối lõm trong thẻ (dùng cho thông số, form phụ) |
| `.sf-glass-panel` | Panel kính mờ nổi trên bản đồ / popover |
| `.sf-eyebrow` | Nhãn phụ cỡ nhỏ, màu dịu (không viết hoa) |
| `.sf-metric` | Số liệu lớn, `tabular-nums` |
| `.sf-delta` | Chênh lệch kỳ trước, mặc định xanh; thêm `.sf-delta-down` cho giảm |
| `.sf-input`, `.sf-select` | Ô nhập chuẩn |
| `.sf-skeleton`, `.sf-scanline` | Trạng thái đang tải |
| `.sf-map-dark` | Đảo màu canvas bản đồ ở chế độ tối |
| `.sf-auth-page`, `.sf-auth-hero`, `.sf-visual-frame` | Trang đăng nhập 3 màn cuộn |

---

## 4. Chuyển động

Mức "vừa phải": mượt nhưng không gây mệt khi dùng lâu.

| Hiệu ứng | Cách dùng |
|---|---|
| Chuyển trang | `<PageTransition>` trong `(dashboard)/layout.tsx` — remount theo pathname, chạy `sf-rise-sm` |
| Lưới thẻ xuất hiện lần lượt | `<Stagger>` hoặc lớp `.sf-stagger` (delay 45ms/thẻ) |
| Hiện khi cuộn tới | `<Reveal delay={ms}>` — IntersectionObserver |
| Số đếm tăng dần | `<CountUp value={n} />` — easing cubic, tôn trọng `prefers-reduced-motion` |
| Con trượt chỉ mục | Sidebar, `<Segmented>`, `<ThemeSwitch>` — nền trượt bằng `ease-spring` |
| Chuyển sáng/tối | `ThemeContext` gắn tạm lớp `.sf-theme-transition` 460ms để màu chuyển mượt |
| Cảnh báo | `.animate-sf-pulse-ring` (SOS), `.animate-sf-pulse-dot` (chấm realtime) |

Toàn bộ animation tắt khi hệ điều hành bật `prefers-reduced-motion: reduce`.

---

## 5. Thư viện component — `components/ui`

```tsx
import { Card, Button, Badge, StatCard, Table, ... } from "@/components/ui";
```

**Bố cục**: `Card`, `CardHeader`, `SectionTitle`, `Toolbar`, `Modal`, `Drawer`, `Tabs`

**Hành động**: `Button` (primary / accent / outline / subtle / ghost / danger), `IconButton`, `DropdownButton`, `MenuItem`

**Hiển thị dữ liệu**: `StatCard`, `CountUp`, `ProgressBar`, `ScoreRing`, `InfoRow`, `Callout`, `Badge`, `StatusDot`, `StatusLabel`

**Bảng**: `TableShell` > `Table` > `Tr` / `Td`, kèm `SkeletonRows`, `EmptyState`

**Biểu mẫu**: `Field`, `TextInput`, `Select`, `Switch`, `SearchInput`, `Segmented`

**Trạng thái**: `Skeleton`, `StatSkeletonGrid`, `EmptyState`

**Chuyển động**: `PageTransition`, `Stagger`, `Reveal`

---

## 6. Chế độ sáng / tối

- `ThemeContext` hỗ trợ 3 chế độ: `light` / `dark` / `system`, lưu ở
  `localStorage["safefleet-theme"]`.
- Script chặn nhấp nháy (FOUC) đặt inline trong `app/layout.tsx`, chạy trước khi
  React hydrate và đồng bộ cả `<meta name="theme-color">`.
- Bộ chuyển: `components/layout/ThemeSwitch.tsx` — dạng đầy đủ ở chân sidebar và
  trang đăng nhập, dạng nút xoay vòng khi sidebar thu gọn.
- Biểu đồ Recharts không đọc được CSS variable trong mọi thuộc tính SVG, nên
  `reports/page.tsx` đọc `resolvedTheme` và chọn bảng màu literal tương ứng —
  đây là ngoại lệ có chủ đích, vẫn giới hạn trong dải teal → amber.

---

## 7. Bố cục ứng dụng

```
app/layout.tsx                 script chống FOUC + providers
└── (dashboard)/layout.tsx     Sidebar + Header + PageTransition + chặn theo quyền
    ├── Sidebar.tsx            6 nhóm menu, con trượt chỉ mục, badge realtime, thu gọn có ghi nhớ
    ├── Header.tsx             tiêu đề trang, Ctrl+K, trạng thái realtime, chuông thông báo (API thật)
    └── CommandSearch.tsx      tìm nhanh xe / tài xế / chuyến / cảnh báo / sự cố
```

Sidebar rộng 264px, thu gọn còn 76px; trạng thái lưu ở
`localStorage["safefleet-sidebar-collapsed"]`.

---

## 8. Thay đổi phía dữ liệu

Backend đã có `/api/v1/notifications` nhưng frontend chưa gọi. Đã bổ sung vào
`lib/safeFleetApi.ts`:

- `notifications()` — GET danh sách thông báo người dùng hiện tại
- `markNotificationRead(id)` — PATCH đánh dấu đã đọc
- `markAllNotificationsRead()` — PATCH đánh dấu đã đọc tất cả
- `reportVehicleStatus()`, `reportHighRiskDrivers()`, `maintenanceDueAlerts()`

Chuông thông báo trên Header dùng dữ liệu thật, tự làm mới mỗi 45 giây.

---

## 9. Quy ước khi viết trang mới

1. Không viết class màu Tailwind gốc (`bg-blue-500`, `text-slate-700`…).
   Dùng token hoặc component có sẵn.
2. Không viết `dark:` variant. Token đã lo phần đó.
3. Trạng thái nghiệp vụ → `toneOf()`, không tự chọn màu.
4. Mọi bảng bọc trong `TableShell` + `Table` để đồng nhất header, viền, trạng
   thái rỗng và skeleton.
5. Lưới thẻ thống kê bọc trong `<Stagger>`.
6. Nút chính của trang là `variant="primary"`; mỗi màn hình chỉ nên có một
   hành động primary nổi bật.
