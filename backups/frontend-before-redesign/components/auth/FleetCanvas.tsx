"use client";

import { useEffect, useRef } from "react";
import { useTheme } from "@/context/ThemeContext";

/**
 * FleetCanvas — nền động mô phỏng mạng lưới tuyến đường của đội xe.
 * Vẽ bằng Canvas 2D: lưới nền, các tuyến, xe chạy có vệt đuôi, nút trạm và
 * điểm sự cố nhấp nháy. Màu lấy theo chế độ sáng/tối, chỉ dùng teal + amber.
 */

type P = [number, number];

/** Tuyến đường ở toạ độ chuẩn hoá 0..1 (tràn nhẹ ra ngoài khung cho tự nhiên). */
const ROUTES: P[][] = [
  [
    [-0.04, 0.74], [0.12, 0.68], [0.25, 0.72], [0.38, 0.59],
    [0.51, 0.62], [0.63, 0.49], [0.77, 0.53], [0.9, 0.43], [1.04, 0.47],
  ],
  [
    [-0.04, 0.27], [0.11, 0.32], [0.25, 0.21], [0.4, 0.26],
    [0.53, 0.17], [0.68, 0.23], [0.83, 0.15], [1.04, 0.19],
  ],
  [
    [0.07, 1.05], [0.17, 0.9], [0.3, 0.85], [0.37, 0.68],
    [0.49, 0.6], [0.57, 0.44], [0.69, 0.34], [0.75, 0.18], [0.87, 0.06], [0.92, -0.05],
  ],
  [
    [1.05, 0.88], [0.9, 0.81], [0.77, 0.87], [0.63, 0.79],
    [0.49, 0.85], [0.35, 0.79], [0.21, 0.87], [0.06, 0.81], [-0.05, 0.88],
  ],
  [
    [0.31, -0.05], [0.35, 0.13], [0.28, 0.29], [0.35, 0.45],
    [0.29, 0.61], [0.35, 0.77], [0.28, 0.95], [0.33, 1.06],
  ],
  [
    [-0.05, 0.5], [0.15, 0.47], [0.3, 0.51], [0.45, 0.44],
    [0.6, 0.47], [0.72, 0.4], [0.88, 0.44], [1.05, 0.38],
  ],
];

/** Tuyến được vẽ nét đứt chạy — tạo cảm giác dòng dữ liệu. */
const FLOW_ROUTES = new Set([2, 5]);

/** Trạm / điểm dừng. */
const NODES: P[] = [
  [0.25, 0.72], [0.63, 0.49], [0.4, 0.26], [0.83, 0.15],
  [0.49, 0.85], [0.35, 0.45], [0.72, 0.4], [0.17, 0.9],
];

/** Điểm sự cố phát sóng cảnh báo. */
const ALERTS: P[] = [
  [0.77, 0.53],
  [0.29, 0.61],
];

interface Unit {
  route: number;
  dist: number;
  speed: number;
  trail: { x: number; y: number }[];
  accent: boolean;
}

const UNITS: Omit<Unit, "trail">[] = [
  { route: 0, dist: 0.05, speed: 46, accent: false },
  { route: 0, dist: 0.62, speed: 38, accent: true },
  { route: 1, dist: 0.3, speed: 52, accent: false },
  { route: 2, dist: 0.18, speed: 34, accent: false },
  { route: 2, dist: 0.74, speed: 41, accent: false },
  { route: 3, dist: 0.44, speed: 44, accent: true },
  { route: 4, dist: 0.12, speed: 30, accent: false },
  { route: 5, dist: 0.55, speed: 48, accent: false },
  { route: 5, dist: 0.9, speed: 36, accent: false },
];

/**
 * Hình minh hoạ nằm trong khung riêng (không có chữ đè lên) nên các nét được
 * vẽ đậm hơn mức trang trí, giúp người mắt kém vẫn nhìn rõ đường tuyến.
 */
function palette(dark: boolean) {
  return dark
    ? {
        grid: "rgba(200, 226, 236, 0.07)",
        route: "rgba(110, 231, 205, 0.38)",
        routeFlow: "rgba(255, 199, 77, 0.55)",
        node: "rgba(110, 231, 205, 0.85)",
        nodeCore: "#0a151d",
        unit: "#6ee7cd",
        unitAccent: "#ffc74d",
        alert: "#ff8085",
      }
    : {
        grid: "rgba(16, 28, 37, 0.075)",
        route: "rgba(8, 127, 115, 0.38)",
        routeFlow: "rgba(168, 91, 7, 0.5)",
        node: "rgba(6, 104, 95, 0.85)",
        nodeCore: "#ffffff",
        unit: "#06685f",
        unitAccent: "#a85b07",
        alert: "#c5343a",
      };
}

export default function FleetCanvas({ className }: { className?: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { resolvedTheme } = useTheme();

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const colors = palette(resolvedTheme === "dark");
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    let width = 0;
    let height = 0;
    let raf = 0;
    let last = performance.now();
    let elapsed = 0;

    /** Toạ độ pixel + độ dài tích luỹ của từng tuyến (tính lại khi đổi kích thước). */
    let geometry: { pts: { x: number; y: number }[]; acc: number[]; total: number }[] = [];

    const units: Unit[] = UNITS.map((u) => ({ ...u, trail: [] }));

    const build = () => {
      geometry = ROUTES.map((route) => {
        const pts = route.map(([nx, ny]) => ({ x: nx * width, y: ny * height }));
        const acc: number[] = [0];
        let total = 0;
        for (let i = 1; i < pts.length; i += 1) {
          total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
          acc.push(total);
        }
        return { pts, acc, total };
      });
      units.forEach((u) => (u.trail = []));
    };

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const rect = canvas.getBoundingClientRect();
      width = rect.width;
      height = rect.height;
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      build();
    };

    /** Vị trí trên tuyến theo quãng đường đã đi. */
    const pointAt = (routeIndex: number, distance: number) => {
      const geo = geometry[routeIndex];
      if (!geo || geo.total === 0) return { x: 0, y: 0, angle: 0 };
      const d = ((distance % geo.total) + geo.total) % geo.total;
      let i = 1;
      while (i < geo.acc.length - 1 && geo.acc[i] < d) i += 1;
      const segStart = geo.pts[i - 1];
      const segEnd = geo.pts[i];
      const segLen = geo.acc[i] - geo.acc[i - 1] || 1;
      const t = (d - geo.acc[i - 1]) / segLen;
      return {
        x: segStart.x + (segEnd.x - segStart.x) * t,
        y: segStart.y + (segEnd.y - segStart.y) * t,
        angle: Math.atan2(segEnd.y - segStart.y, segEnd.x - segStart.x),
      };
    };

    const drawGrid = () => {
      const step = 68;
      ctx.strokeStyle = colors.grid;
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let x = 0; x <= width; x += step) {
        ctx.moveTo(Math.round(x) + 0.5, 0);
        ctx.lineTo(Math.round(x) + 0.5, height);
      }
      for (let y = 0; y <= height; y += step) {
        ctx.moveTo(0, Math.round(y) + 0.5);
        ctx.lineTo(width, Math.round(y) + 0.5);
      }
      ctx.stroke();
    };

    const drawRoutes = (time: number) => {
      ctx.lineCap = "round";
      ctx.lineJoin = "round";

      geometry.forEach((geo, index) => {
        const isFlow = FLOW_ROUTES.has(index);
        ctx.beginPath();
        ctx.moveTo(geo.pts[0].x, geo.pts[0].y);
        for (let i = 1; i < geo.pts.length; i += 1) ctx.lineTo(geo.pts[i].x, geo.pts[i].y);

        if (isFlow) {
          ctx.setLineDash([14, 12]);
          ctx.lineDashOffset = -time * 26;
          ctx.strokeStyle = colors.routeFlow;
          ctx.lineWidth = 1.6;
        } else {
          ctx.setLineDash([]);
          ctx.strokeStyle = colors.route;
          ctx.lineWidth = 2;
        }
        ctx.stroke();
      });
      ctx.setLineDash([]);
    };

    const drawNodes = () => {
      NODES.forEach(([nx, ny]) => {
        const x = nx * width;
        const y = ny * height;
        ctx.beginPath();
        ctx.arc(x, y, 4.5, 0, Math.PI * 2);
        ctx.fillStyle = colors.nodeCore;
        ctx.fill();
        ctx.lineWidth = 1.6;
        ctx.strokeStyle = colors.node;
        ctx.stroke();
      });
    };

    const drawAlerts = (time: number) => {
      ALERTS.forEach(([nx, ny], index) => {
        const x = nx * width;
        const y = ny * height;
        const phase = (time * 0.55 + index * 0.5) % 1;
        const radius = 8 + phase * 46;

        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2);
        ctx.strokeStyle = colors.alert;
        ctx.globalAlpha = (1 - phase) * 0.5;
        ctx.lineWidth = 1.8;
        ctx.stroke();
        ctx.globalAlpha = 1;

        ctx.beginPath();
        ctx.arc(x, y, 4.5, 0, Math.PI * 2);
        ctx.fillStyle = colors.alert;
        ctx.fill();
      });
    };

    const drawUnits = (delta: number) => {
      units.forEach((unit) => {
        const geo = geometry[unit.route];
        if (!geo) return;

        if (!reduce) unit.dist += unit.speed * delta;
        const pos = pointAt(unit.route, unit.dist * (geo.total / 900));

        unit.trail.push({ x: pos.x, y: pos.y });
        if (unit.trail.length > 22) unit.trail.shift();

        const color = unit.accent ? colors.unitAccent : colors.unit;

        // Vệt đuôi
        for (let i = 1; i < unit.trail.length; i += 1) {
          const a = unit.trail[i - 1];
          const b = unit.trail[i];
          ctx.beginPath();
          ctx.moveTo(a.x, a.y);
          ctx.lineTo(b.x, b.y);
          ctx.strokeStyle = color;
          ctx.globalAlpha = (i / unit.trail.length) * 0.45;
          ctx.lineWidth = 2.4;
          ctx.stroke();
        }
        ctx.globalAlpha = 1;

        // Quầng sáng
        ctx.beginPath();
        ctx.arc(pos.x, pos.y, 9, 0, Math.PI * 2);
        ctx.fillStyle = color;
        ctx.globalAlpha = 0.16;
        ctx.fill();
        ctx.globalAlpha = 1;

        // Thân xe
        ctx.beginPath();
        ctx.arc(pos.x, pos.y, 3.6, 0, Math.PI * 2);
        ctx.fillStyle = color;
        ctx.fill();
      });
    };

    const frame = (now: number) => {
      const delta = Math.min((now - last) / 1000, 0.05);
      last = now;
      elapsed += delta;

      ctx.clearRect(0, 0, width, height);
      drawGrid();
      drawRoutes(elapsed);
      drawUnits(delta);
      drawNodes();
      drawAlerts(elapsed);

      raf = requestAnimationFrame(frame);
    };

    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(canvas);

    if (reduce) {
      // Vẽ một khung tĩnh khi người dùng tắt hiệu ứng chuyển động.
      ctx.clearRect(0, 0, width, height);
      drawGrid();
      drawRoutes(0);
      drawUnits(0);
      drawNodes();
      drawAlerts(0);
    } else {
      raf = requestAnimationFrame(frame);
    }

    return () => {
      cancelAnimationFrame(raf);
      observer.disconnect();
    };
  }, [resolvedTheme]);

  return <canvas ref={canvasRef} aria-hidden className={className} />;
}
