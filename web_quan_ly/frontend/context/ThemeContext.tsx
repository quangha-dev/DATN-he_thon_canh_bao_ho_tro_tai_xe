"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

export type ThemeMode = "light" | "dark" | "system";

interface ThemeContextValue {
  mode: ThemeMode;
  resolvedTheme: "light" | "dark";
  setMode: (mode: ThemeMode) => void;
  toggleTheme: () => void;
  /** True trong lúc đang chuyển sáng/tối — dùng để khóa animation phụ */
  isSwitching: boolean;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

const STORAGE_KEY = "safefleet-theme";
const TRANSITION_CLASS = "sf-theme-transition";
const TRANSITION_MS = 460;

function systemTheme(): "light" | "dark" {
  if (typeof window === "undefined") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function applyTheme(mode: ThemeMode) {
  const resolved = mode === "system" ? systemTheme() : mode;
  const root = document.documentElement;
  root.classList.toggle("dark", resolved === "dark");
  root.dataset.theme = resolved;
  root.style.colorScheme = resolved;

  // Cập nhật theme-color để thanh trình duyệt trên mobile khớp giao diện
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute("content", resolved === "dark" ? "#060e14" : "#eef2f4");

  return resolved;
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [mode, setModeState] = useState<ThemeMode>("system");
  const [resolvedTheme, setResolvedTheme] = useState<"light" | "dark">("light");
  const [isSwitching, setIsSwitching] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    const initialMode: ThemeMode =
      stored === "light" || stored === "dark" || stored === "system" ? stored : "system";
    setModeState(initialMode);
    setResolvedTheme(applyTheme(initialMode));
  }, []);

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const onSystemThemeChange = () => {
      if (mode === "system") setResolvedTheme(applyTheme("system"));
    };
    media.addEventListener("change", onSystemThemeChange);
    return () => media.removeEventListener("change", onSystemThemeChange);
  }, [mode]);

  useEffect(
    () => () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    },
    []
  );

  const setMode = useCallback((nextMode: ThemeMode) => {
    const root = document.documentElement;
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (!reduce) {
      root.classList.add(TRANSITION_CLASS);
      setIsSwitching(true);
      if (timerRef.current) clearTimeout(timerRef.current);
      timerRef.current = setTimeout(() => {
        root.classList.remove(TRANSITION_CLASS);
        setIsSwitching(false);
      }, TRANSITION_MS);
    }

    window.localStorage.setItem(STORAGE_KEY, nextMode);
    setModeState(nextMode);
    setResolvedTheme(applyTheme(nextMode));
  }, []);

  const toggleTheme = useCallback(() => {
    setMode(resolvedTheme === "dark" ? "light" : "dark");
  }, [resolvedTheme, setMode]);

  const value = useMemo(
    () => ({ mode, resolvedTheme, setMode, toggleTheme, isSwitching }),
    [mode, resolvedTheme, setMode, toggleTheme, isSwitching]
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) throw new Error("useTheme phải được dùng bên trong ThemeProvider");
  return context;
}
