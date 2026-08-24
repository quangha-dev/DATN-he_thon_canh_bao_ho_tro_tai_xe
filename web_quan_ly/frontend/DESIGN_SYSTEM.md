# SafeFleet — Design System (bản dựng lại 2026)

Tài liệu tham chiếu cho giao diện web quản lý sau đợt dựng lại theo bản thiết kế
`Design/Web quản lý (standalone).html`.

Toàn bộ logic gọi API giữ nguyên; chỉ lớp trình bày được viết lại.

---

## 0. Phong cách thị giác

Bảng điều khiển kiểu SaaS mềm: nền xám ngả lục rất nhạt (`#f2f6f5`), thẻ trắng bo
**28px**, tách nhau bằng bóng khuếch tán rộng thay vì viền đậm.

Quy tắc điểm nhấn: mỗi màn hình có **đúng một** khối tô đặc màu thương hiệu —
`<StatCard filled>` (thẻ số liệu đầu tiên) hoặc `<HeroPanel>` (dải nhấn tối).
Phần còn lại là thẻ trắng; màu chỉ xuất hiện thêm ở ô icon, huy hiệu và chấm
trạng thái.

Chữ: **Plus Jakarta Sans** cho nội dung, **JetBrains Mono** cho số liệu, mã, biển
số và mốc thời gian (class `.sf-mono`, `.sf-metric`). Cả hai nạp qua Google Fonts
ở `app/layout.tsx`, có dải dự phòng Inter / system-ui khi máy không tải được.

---

## 1. Nguyên tắc màu (bắt buộc)

Mỗi trang chỉ dùng **2 màu có sắc độ** cộng dải trung tính:

| Vai trò | Màu | Token | Dùng cho |
|---|---|---|---|
| Primary | Teal | `--sf-primary` | Nút chính, chỉ mục đang chọn, biểu đồ, marker xe đang chạy |
| Accent | Amber | `--sf-accent` | Nhấn mạnh phụ, badge cảnh báo AI, ngưỡng gần giới hạn |
| Neutral | Ink (xanh lạnh) | `--sf-ink-*` | Nền, chữ, viền, bóng đổ |

**Màu semantic** (`--sf-success` / `--sf-warning` / `--sf-danger` / `--sf-info`)
**chỉ** dùng cho tín hiệu trạng thái nhỏ: chấm, huy hiệu, viền trái, icon.

### Cách lấy màu trạng thái

Không viết màu thủ công. Dùng:

```tsx
import { toneOf, Badge } from "@/components/ui";

<Badge tone={toneOf(alert.severity)} dot>{SEVERITY_VI[alert.severity]}</Badge>
```

Bảng ánh xạ nằm ở `STATUS_TONE` trong `components/ui/primitives.tsx` — nguồn chân
lý duy nhất cho màu trạng thái.

---

## 2. Token

Toàn bộ token nằm ở `app/globals.css`, khai báo hai lần: `:root` (sáng) và
`.dark` (tối). Mọi component đọc qua CSS variable nên **không cần viết `dark:`
variant**.

Nhóm token: màu (`--sf-primary-*`, `--sf-accent-*`, `--sf-ink-*`, semantic), bề
mặt (`--sf-bg`, `--sf-bg-card`, `--sf-bg-inset`, `--sf-bg-card-alt`,
`--sf-bg-header`), dải nhấn (`--sf-hero`, `--sf-hero-shadow`, `--sf-hero-line`),
sidebar (`--sf-pill`, `--sf-pill-line`, `--sf-hover`), chữ, viền, bóng, bo góc
(`--sf-r-xs` 10px → `--sf-r-xl` 28px, `--sf-r-row` 20px, `--sf-r-pill`), chuyển
động, và kích thước khung (`--sidebar-width` 268px, `--sidebar-collapsed-width`
84px, `--header-height` 74px).

---

## 3. Lớp tiện ích

| Lớp | Công dụng |
|---|---|
| `.sf-surface` | Thẻ chuẩn: nền trắng, bo 28px, hairline rất nhạt, bóng mềm |
| `.sf-surface-filled` | Thẻ tô đặc màu thương hiệu — điểm nhấn duy nhất mỗi màn hình |
| `.sf-hero-panel` | Dải nhấn tối gradient teal, dùng cho tổng quan / gợi ý AI |
| `.sf-hero-glow` | Quầng sáng thở nhẹ đặt trong dải nhấn |
| `.sf-hero-tile`, `.sf-hero-chip` | Ô số liệu và chip nhỏ bên trong dải nhấn |
| `.sf-row`, `.sf-row-head`, `.sf-row-clickable` | Hàng bảng dạng thẻ (grid, không dùng `<table>`) |
| `.sf-chip`, `.sf-chip-active` | Chip lọc dạng viên thuốc |
| `.sf-search-box` | Ô tìm trong thẻ, nền lõm, bo 14px |
| `.sf-pill-primary`, `.sf-pill-ghost` | Nút chính / nút phụ dạng viên thuốc |
| `.sf-nav-pill`, `.sf-nav-bar`, `.sf-nav-item` | Chỉ mục trượt và mục menu ở sidebar |
| `.sf-track` (+ `-warn` / `-danger` / `-info`) | Thanh tiến độ mảnh |
| `.sf-icon-chip` | Ô icon 38×38 bo 14px nền teal nhạt |
| `.sf-mono`, `.sf-metric` | Chữ đơn cách cho mã, biển số, số liệu lớn |
| `.sf-eyebrow` | Nhãn phụ viết hoa, giãn chữ `.1em` |
| `.sf-glass-panel` | Panel kính mờ nổi trên bản đồ / popover |
| `.sf-map-dark` | Đảo màu canvas bản đồ ở chế độ tối |

---

## 4. Chuyển động

| Hiệu ứng | Cách dùng |
|---|---|
| Chuyển trang | `<PageTransition>` trong `(dashboard)/layout.tsx` |
| Thẻ số liệu xuất hiện | `animate-sf-pop`, độ trễ `delay={0/70/140/210}` trên `StatCard` |
| Hàng bảng xuất hiện | `animate-sf-slide-left`, độ trễ tăng dần theo chỉ số hàng |
| Cột biểu đồ mọc lên | `animate-sf-bar` |
| Con trượt chỉ mục sidebar | `.sf-nav-pill` + `.sf-nav-bar`, easing spring 460ms |
| Cảnh báo | `.animate-sf-pulse-ring` (SOS), `.animate-sf-pulse-dot` (chấm realtime) |

Toàn bộ animation tắt khi hệ điều hành bật `prefers-reduced-motion: reduce`.

---

## 5. Thư viện component — `components/ui`

```tsx
import { StatCard, TableCard, TableToolbar, DataTable, ... } from "@/components/ui";
```

**Nền tảng** (`primitives.tsx`): `Card`, `CardHeader`, `SectionTitle`, `Toolbar`,
`Modal`, `Drawer`, `Tabs`, `Button`, `IconButton`, `DropdownButton`, `MenuItem`,
`StatCard`, `CountUp`, `ProgressBar`, `ScoreRing`, `InfoRow`, `Callout`, `Badge`
(có `dot`), `StatusDot`, `StatusLabel`, `TableShell`/`Table`/`Tr`/`Td` (bảng cũ,
giữ cho tương thích), `Field`, `TextInput`, `Select`, `Switch`, `SearchInput`,
`Segmented`, `Skeleton`, `EmptyState`, `toneOf`, `TONE`, `STATUS_TONE`.

**Khối dữ liệu mới** (`data.tsx`) — dựng theo bản thiết kế:

```tsx
<HeroPanel>                       {/* dải nhấn tối */}
  <HeroTile value={12} label="Đang vận hành" tone="warning" delay={0} />
</HeroPanel>

<TableCard toolbar={
  <TableToolbar
    search={{ value, onChange, placeholder }}
    filters={<FilterChips items={chips} value={key} onChange={setKey} />}
    extra={<Select … />}
    action={<button className="sf-pill-primary">…</button>}
  />
}>
  <DataTable
    grid="1.5fr 1.1fr 1fr .9fr 1.1fr"   /* số cột phải khớp columns */
    columns={["Tài xế", …]}
    loading={isLoading}
    empty={{ icon, title, description }}
    rows={items.map(x => ({ key, onClick, cells: [ … ] }))}
  />
</TableCard>

<CellText text="…" sub="…" mono strong color="var(--sf-danger)" icon={Car} />
<CellProgress label="KH 09:00 · ETA 08:45" percent={65} tone="warning" />
<MiniStat label="Tốc độ hiện tại" value="42 km/h" tone="danger" />
<DetailRow label="Tài xế" value="Nguyễn Văn An" mono />
```

**Chuyển động** (`motion.tsx`): `PageTransition`, `Stagger`, `Reveal`.

---

## 6. Bố cục ứng dụng

```
app/layout.tsx                 script chống FOUC + bộ chữ + providers
└── (dashboard)/layout.tsx     Sidebar + Header + PageTransition + chặn theo quyền
    ├── Sidebar.tsx            7 nhóm menu, vệt chỉ mục trượt, badge realtime,
    │                          thu gọn còn 84px, đổi nền sáng/tối + đăng xuất ở chân
    ├── Header.tsx             nhãn nhóm + tên trang, trạng thái realtime,
    │                          ô tìm Ctrl K, chuông thông báo, thẻ hồ sơ
    └── CommandSearch.tsx      tìm nhanh xe / tài xế / chuyến / cảnh báo / sự cố
```

Sidebar rộng 268px, thu gọn còn 84px, ghi nhớ ở
`localStorage["safefleet-sidebar-collapsed"]`.

**Lưu ý kỹ thuật**: các nhóm menu trong `<nav>` **không được** đặt
`position: relative` — nếu không `offsetTop` của mục sẽ tính theo nhóm thay vì
theo `<nav>`, làm vệt chỉ mục nhảy sai chỗ.

---

## 7. Ba khuôn màn hình

1. **Danh sách** (9 trang: tài xế, tài khoản, phương tiện, chuyến đi, duyệt
   phiếu, cảnh báo, sự cố, thiết bị, bảo trì)
   → 4 thẻ số liệu (thẻ đầu `filled`) + `TableCard` chứa `TableToolbar` và
   `DataTable`.
2. **Bản đồ** (bản đồ realtime, điểm ngập) → MapLibre thật, lớp phủ kính mờ:
   ô tìm, nút danh sách xe, cụm zoom, panel danh sách trái, panel chi tiết phải,
   chú giải dưới. `MapView` nhận `ref` kiểu `MapViewHandle` để trang tự điều
   khiển `zoomIn / zoomOut / reset / flyTo`.
3. **Bảng làm việc** (trung tâm điều hành, điều phối, báo cáo, cấu hình, hồ sơ)
   → lưới hai cột, một cột là dải nhấn tối hoặc biểu mẫu, cột kia là danh sách
   việc / bảng chỉ số.

---

## 8. Quy ước khi viết trang mới

1. Không viết class màu Tailwind gốc (`bg-blue-500`, `text-slate-700`…).
2. Không viết `dark:` variant — token đã lo phần đó.
3. Trạng thái nghiệp vụ → `toneOf()`, không tự chọn màu.
4. Bảng danh sách dùng `DataTable`; số phần tử `cells` phải khớp `columns` và
   `grid`.
5. Bộ lọc dựng **động từ enum backend**, chỉ hiện giá trị thực sự có dữ liệu,
   luôn có chip "Tất cả" đứng đầu — không cắt bớt theo dữ liệu mẫu của bản
   thiết kế.
6. Mỗi màn hình chỉ một nút hành động chính (`sf-pill-primary`).
