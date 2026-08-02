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
        <div className="fixed inset-0 z-50 flex items-start justify-center pt-[10vh] px-4">
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
            onClick={onClose}
          />

          {/* Modal Container */}
          <motion.div
            ref={containerRef}
            initial={{ opacity: 0, scale: 0.97, y: -8 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.97, y: -8 }}
            transition={{ duration: 0.2 }}
            className="relative w-full max-w-xl bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl overflow-hidden z-10"
          >
            {/* Search Input Header */}
            <div className="flex items-center gap-3 px-4 py-3.5 border-b border-slate-100 dark:border-slate-800">
              <Search className="w-5 h-5 text-slate-400" />
              <input
                ref={inputRef}
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Tìm xe, tài xế, chuyến đi, cảnh báo..."
                className="flex-1 bg-transparent border-none text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none text-sm"
              />
              <button
                onClick={onClose}
                className="p-1 rounded-md text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Results body */}
            <div className="max-h-[360px] overflow-y-auto p-2">
              {results.length > 0 ? (
                <div className="space-y-0.5">
                  {results.map((item, idx) => {
                    const active = idx === selectedIndex;
                    return (
                      <button
                        key={`${item.type}-${item.id}`}
                        onClick={() => handleSelect(item)}
                        className={cn(
                          "w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-left transition-all duration-150 group",
                          active
                            ? "bg-blue-600 text-white"
                            : "hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300"
                        )}
                      >
                        {/* Icon based on type */}
                        <div
                          className={cn(
                            "w-8 h-8 rounded-lg flex items-center justify-center transition-colors",
                            active
                              ? "bg-blue-500 text-white"
                              : "bg-slate-100 dark:bg-slate-800 text-slate-400 group-hover:text-slate-600 dark:group-hover:text-slate-200"
                          )}
                        >
                          {item.type === "vehicle" && <Truck className="w-4.5 h-4.5" />}
                          {item.type === "driver" && <User className="w-4.5 h-4.5" />}
                          {item.type === "trip" && <Navigation className="w-4.5 h-4.5" />}
                          {item.type === "alert" && <AlertTriangle className="w-4.5 h-4.5" />}
                          {item.type === "incident" && <Siren className="w-4.5 h-4.5" />}
                        </div>

                        {/* Text */}
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-semibold truncate leading-none mb-0.5">
                            {item.title}
                          </p>
                          <p
                            className={cn(
                              "text-xs truncate leading-none",
                              active ? "text-blue-100" : "text-slate-400 dark:text-slate-500"
                            )}
                          >
                            {item.subtitle}
                          </p>
                        </div>

                        {/* Keyboard action hint */}
                        {active && (
                          <CornerDownLeft className="w-4 h-4 text-blue-200 flex-shrink-0 animate-pulse" />
                        )}
                      </button>
                    );
                  })}
                </div>
              ) : query.trim() ? (
                <div className="text-center py-8 text-slate-400 dark:text-slate-500">
                  Không tìm thấy kết quả nào cho &quot;<span className="font-semibold">{query}</span>&quot;
                </div>
              ) : (
                <div className="py-6 px-4 text-center">
                  <p className="text-xs font-semibold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-2">
                    Lối tắt tìm kiếm nhanh
                  </p>
                  <div className="flex justify-center gap-6 text-[11px] text-slate-400 dark:text-slate-500">
                    <span className="flex items-center gap-1">
                      <Truck className="w-3.5 h-3.5" /> Xe
                    </span>
                    <span className="flex items-center gap-1">
                      <User className="w-3.5 h-3.5" /> Tài xế
                    </span>
                    <span className="flex items-center gap-1">
                      <Navigation className="w-3.5 h-3.5" /> Chuyến đi
                    </span>
                    <span className="flex items-center gap-1">
                      <AlertTriangle className="w-3.5 h-3.5" /> Cảnh báo
                    </span>
                    <span className="flex items-center gap-1">
                      <Siren className="w-3.5 h-3.5" /> Sự cố
                    </span>
                  </div>
                </div>
              )}
            </div>

            {/* Footer / Instructions */}
            <div className="px-4 py-2 bg-slate-50 dark:bg-slate-950 border-t border-slate-100 dark:border-slate-800 text-[11px] text-slate-400 dark:text-slate-500 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <span>Di chuyển: <kbd className="bg-white dark:bg-slate-800 px-1 py-0.5 rounded border dark:border-slate-700">↑↓</kbd></span>
                <span>Chọn: <kbd className="bg-white dark:bg-slate-800 px-1 py-0.5 rounded border dark:border-slate-700">Enter</kbd></span>
              </div>
              <span>Đóng: <kbd className="bg-white dark:bg-slate-800 px-1 py-0.5 rounded border dark:border-slate-700">Esc</kbd></span>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}
