"use client";

import { useEffect, useState, useRef, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AnimatePresence, motion } from "framer-motion";
import {
  Search,
  Truck,
  User,
  Navigation,
  AlertTriangle,
  Siren,
  X,
  CornerDownLeft,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/context/AuthContext";
import { canAccessPath } from "@/lib/accessControl";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { Alert, Driver, Incident, Trip, Vehicle } from "@/types";

interface CommandSearchProps {
  isOpen: boolean;
  onClose: () => void;
}

function Kbd({ children }: { children: React.ReactNode }) {
  return (
    <kbd className="rounded border border-[var(--sf-border)] bg-[var(--sf-bg-card)] px-1.5 py-0.5 font-mono text-[12px] font-bold text-sf-text-secondary">
      {children}
    </kbd>
  );
}

type SearchResultItem =
  | { type: "vehicle"; id: string; title: string; subtitle: string; path: string }
  | { type: "driver"; id: string; title: string; subtitle: string; path: string }
  | { type: "trip"; id: string; title: string; subtitle: string; path: string }
  | { type: "alert"; id: string; title: string; subtitle: string; path: string }
  | { type: "incident"; id: string; title: string; subtitle: string; path: string };

export default function CommandSearch({ isOpen, onClose }: CommandSearchProps) {
  const router = useRouter();
  const { user } = useAuth();
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResultItem[]>([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [trips, setTrips] = useState<Trip[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const inputRef = useRef<HTMLInputElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Auto focus input when opened
  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 50);
      setQuery("");
      setResults([]);
      setSelectedIndex(0);
    }
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen) return;
    let cancelled = false;

    const loadSearchData = async () => {
      const canSearch = (path: string) => !user || canAccessPath(user.role, path);
      const empty = Promise.resolve([]);
      const [vehicleData, driverData, tripData, alertData, incidentData] = await Promise.allSettled([
        canSearch("/vehicles") ? safeFleetApi.vehicles() : empty,
        canSearch("/drivers") ? safeFleetApi.drivers() : empty,
        canSearch("/trips") ? safeFleetApi.trips() : empty,
        canSearch("/alerts") ? safeFleetApi.safetyEvents() : empty,
        canSearch("/incidents") ? safeFleetApi.incidents() : empty,
      ]);

      if (!cancelled) {
        setVehicles(vehicleData.status === "fulfilled" ? vehicleData.value : []);
        setDrivers(driverData.status === "fulfilled" ? driverData.value : []);
        setTrips(tripData.status === "fulfilled" ? tripData.value : []);
        setAlerts(alertData.status === "fulfilled" ? alertData.value : []);
        setIncidents(incidentData.status === "fulfilled" ? incidentData.value : []);
      }
    };

    loadSearchData();

    return () => {
      cancelled = true;
    };
  }, [isOpen, user]);

  // Click outside to close
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        onClose();
      }
    }
    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
    }
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [isOpen, onClose]);

  // Handle Search Logic
  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      return;
    }

    const q = query.toLowerCase();
    const tempResults: SearchResultItem[] = [];

    // Search vehicles
    vehicles
      .filter((v) => v.plate.toLowerCase().includes(q) || v.type.toLowerCase().includes(q))
      .slice(0, 3)
      .forEach((v) => {
        tempResults.push({
          type: "vehicle",
          id: v.id,
          title: v.plate,
          subtitle: `${v.type} · ${v.brand} ${v.model}`,
          path: `/vehicles?id=${v.id}`,
        });
      });

    // Search drivers
    drivers
      .filter((d) => d.fullName.toLowerCase().includes(q) || d.phone.includes(q))
      .slice(0, 3)
      .forEach((d) => {
        tempResults.push({
          type: "driver",
          id: d.id,
          title: d.fullName,
          subtitle: `SĐT: ${d.phone} · Bằng ${d.licenseClass}`,
          path: `/drivers?id=${d.id}`,
        });
      });

    // Search trips
    trips
      .filter((t) => t.code.toLowerCase().includes(q) || t.origin.toLowerCase().includes(q) || t.destination.toLowerCase().includes(q))
      .slice(0, 3)
      .forEach((t) => {
        tempResults.push({
          type: "trip",
          id: t.id,
          title: t.code,
          subtitle: `${t.origin} → ${t.destination}`,
          path: `/trips?id=${t.id}`,
        });
      });

    // Search alerts
    alerts
      .filter((a) => a.vehiclePlate.toLowerCase().includes(q) || a.driverName.toLowerCase().includes(q) || a.message.toLowerCase().includes(q))
      .slice(0, 3)
      .forEach((a) => {
        tempResults.push({
          type: "alert",
          id: a.id,
          title: `${a.driverName} - Cảnh báo`,
          subtitle: a.message,
          path: `/alerts?id=${a.id}`,
        });
      });

    // Search incidents
    incidents
      .filter((i) =>
        i.vehiclePlate.toLowerCase().includes(q) ||
        i.driverName.toLowerCase().includes(q) ||
        i.location.toLowerCase().includes(q) ||
        (i.description || "").toLowerCase().includes(q)
      )
      .slice(0, 3)
      .forEach((i) => {
        tempResults.push({
          type: "incident",
          id: i.id,
          title: `${i.vehiclePlate} - Sự cố`,
          subtitle: i.description || i.location,
          path: `/incidents?id=${i.id}`,
        });
      });

    setResults(tempResults);
    setSelectedIndex(0);
  }, [query, vehicles, drivers, trips, alerts, incidents]);

  // Navigate to result
  const handleSelect = useCallback((item: SearchResultItem) => {
    router.push(item.path);
    onClose();
  }, [router, onClose]);

  // Handle keyboard events
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (!isOpen) return;

      if (e.key === "Escape") {
        onClose();
      } else if (e.key === "ArrowDown") {
        e.preventDefault();
        setSelectedIndex((prev) => (results.length > 0 ? (prev + 1) % results.length : 0));
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setSelectedIndex((prev) => (results.length > 0 ? (prev - 1 + results.length) % results.length : 0));
      } else if (e.key === "Enter") {
        e.preventDefault();
        if (results[selectedIndex]) {
          handleSelect(results[selectedIndex]);
        }
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [isOpen, results, selectedIndex, onClose, handleSelect]);

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-[120] flex items-start justify-center px-4 pt-[12vh]">
          {/* Lớp phủ */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 bg-[var(--sf-bg-overlay)] backdrop-blur-[3px]"
            onClick={onClose}
          />

          {/* Hộp thoại */}
          <motion.div
            ref={containerRef}
            initial={{ opacity: 0, scale: 0.97, y: -10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.97, y: -10 }}
            transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
            className="sf-glass-panel relative z-10 w-full max-w-xl overflow-hidden"
          >
            {/* Ô nhập */}
            <div className="flex items-center gap-3 border-b border-[var(--sf-border)] px-4 py-3.5">
              <Search className="h-[18px] w-[18px] flex-shrink-0 text-[var(--sf-primary)]" />
              <input
                ref={inputRef}
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Tìm xe, tài xế, chuyến đi, cảnh báo…"
                className="flex-1 border-none bg-transparent text-[14px] font-medium text-sf-text placeholder:text-sf-text-muted focus:outline-none"
              />
              <button
                type="button"
                onClick={onClose}
                aria-label="Đóng"
                className="grid h-7 w-7 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)] text-sf-text-muted transition-colors hover:bg-[var(--sf-bg-inset)] hover:text-sf-text cursor-pointer"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Kết quả */}
            <div className="max-h-[24rem] overflow-y-auto p-2">
              {results.length > 0 ? (
                <div className="space-y-0.5">
                  {results.map((item, idx) => {
                    const active = idx === selectedIndex;
                    return (
                      <button
                        key={`${item.type}-${item.id}`}
                        onClick={() => handleSelect(item)}
                        onMouseEnter={() => setSelectedIndex(idx)}
                        className={cn(
                          "group flex w-full items-center gap-3 rounded-[var(--sf-r-sm)] px-3 py-2.5 text-left transition-colors duration-[var(--sf-dur-fast)] cursor-pointer",
                          active ? "bg-[var(--sf-primary-soft)]" : "hover:bg-[var(--sf-bg-inset)]"
                        )}
                      >
                        <span
                          className="grid h-8 w-8 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)] transition-colors"
                          style={{
                            background: active ? "var(--sf-primary)" : "var(--sf-bg-inset)",
                            color: active ? "var(--sf-primary-contrast)" : "var(--sf-text-muted)",
                          }}
                        >
                          {item.type === "vehicle" && <Truck className="h-4 w-4" />}
                          {item.type === "driver" && <User className="h-4 w-4" />}
                          {item.type === "trip" && <Navigation className="h-4 w-4" />}
                          {item.type === "alert" && <AlertTriangle className="h-4 w-4" />}
                          {item.type === "incident" && <Siren className="h-4 w-4" />}
                        </span>

                        <span className="min-w-0 flex-1">
                          <span
                            className={cn(
                              "block truncate text-[13px] font-bold leading-tight",
                              active ? "text-[var(--sf-primary)]" : "text-sf-text"
                            )}
                          >
                            {item.title}
                          </span>
                          <span className="mt-0.5 block truncate text-[12.5px] leading-tight text-sf-text-muted">
                            {item.subtitle}
                          </span>
                        </span>

                        {active && (
                          <CornerDownLeft className="h-4 w-4 flex-shrink-0 text-[var(--sf-primary)]" />
                        )}
                      </button>
                    );
                  })}
                </div>
              ) : query.trim() ? (
                <p className="py-10 text-center text-[13px] text-sf-text-muted">
                  Không tìm thấy kết quả cho &quot;
                  <span className="font-bold text-sf-text-secondary">{query}</span>&quot;
                </p>
              ) : (
                <div className="px-4 py-7 text-center">
                  <p className="sf-eyebrow mb-3">Phạm vi tìm kiếm</p>
                  <div className="flex flex-wrap justify-center gap-x-5 gap-y-2 text-[12.5px] font-semibold text-sf-text-muted">
                    <span className="flex items-center gap-1.5">
                      <Truck className="h-3.5 w-3.5" /> Phương tiện
                    </span>
                    <span className="flex items-center gap-1.5">
                      <User className="h-3.5 w-3.5" /> Tài xế
                    </span>
                    <span className="flex items-center gap-1.5">
                      <Navigation className="h-3.5 w-3.5" /> Chuyến đi
                    </span>
                    <span className="flex items-center gap-1.5">
                      <AlertTriangle className="h-3.5 w-3.5" /> Cảnh báo
                    </span>
                    <span className="flex items-center gap-1.5">
                      <Siren className="h-3.5 w-3.5" /> Sự cố
                    </span>
                  </div>
                </div>
              )}
            </div>

            {/* Chân hộp thoại */}
            <div className="flex items-center justify-between border-t border-[var(--sf-border)] bg-[var(--sf-bg-inset)] px-4 py-2.5 text-[12.5px] font-semibold text-sf-text-muted">
              <span className="flex items-center gap-3">
                <span className="flex items-center gap-1.5">
                  <Kbd>↑↓</Kbd> Di chuyển
                </span>
                <span className="flex items-center gap-1.5">
                  <Kbd>Enter</Kbd> Chọn
                </span>
              </span>
              <span className="flex items-center gap-1.5">
                <Kbd>Esc</Kbd> Đóng
              </span>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}
