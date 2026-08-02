"use client";

import { useEffect, useState } from "react";
import {
  Clock,
  ShieldAlert,
  Server,
  Save,
} from "lucide-react";
import { useToast } from "@/context/ToastContext";
import { safeFleetApi, SystemSetting } from "@/lib/safeFleetApi";

export default function SettingsPage() {
  const { showToast } = useToast();
  const [settings, setSettings] = useState<SystemSetting[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  
  // Settings forms
  const [maxContinuousDriving, setMaxContinuousDriving] = useState(240); // 4 hours
  const [warning1, setWarning1] = useState(180); // 3 hours
  const [warning2, setWarning2] = useState(210); // 3.5 hours
  const [criticalWarning, setCriticalWarning] = useState(230); // 3h50m

  const [aiDrowsyEnabled, setAiDrowsyEnabled] = useState(true);
  const [aiPhoneEnabled, setAiPhoneEnabled] = useState(true);
  const [aiDistractEnabled, setAiDistractEnabled] = useState(true);
  const [aiSpeedEnabled, setAiSpeedEnabled] = useState(true);

  const [apiEndpoint, setApiEndpoint] = useState("http://localhost:8080/api/v1");
  const [wsEndpoint, setWsEndpoint] = useState("ws://localhost:8080/ws-native");

  useEffect(() => {
    let cancelled = false;

    const asInt = (key: string, fallback: number, items: SystemSetting[]) => {
      const value = Number(items.find((setting) => setting.key === key)?.value);
      return Number.isFinite(value) ? value : fallback;
    };

    const asBool = (key: string, fallback: boolean, items: SystemSetting[]) => {
      const value = items.find((setting) => setting.key === key)?.value;
      if (value === undefined) return fallback;
      return value === "true";
    };

    const loadSettings = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.settings();
        if (!cancelled) {
          setSettings(data);
          setMaxContinuousDriving(asInt("driving.max_continuous_minutes", 240, data));
          setWarning1(asInt("driving.warn_1_minutes", 180, data));
          setWarning2(asInt("driving.warn_2_minutes", 210, data));
          setCriticalWarning(asInt("driving.critical_minutes", 230, data));
          setAiDrowsyEnabled(asBool("ai.drowsiness_enabled", true, data));
          setAiPhoneEnabled(asBool("ai.phone_usage_enabled", true, data));
          setAiDistractEnabled(asBool("ai.distraction_enabled", true, data));
          setAiSpeedEnabled(asBool("ai.speeding_enabled", true, data));
          setApiEndpoint(process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080/api/v1");
          setWsEndpoint(
            process.env.NEXT_PUBLIC_WS_URL || "ws://localhost:8080/ws-native"
          );
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được cấu hình.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    loadSettings();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  const settingOf = (
    key: string,
    group: SystemSetting["group"],
    value: string,
    valueType: SystemSetting["valueType"],
    description: string
  ): SystemSetting => {
    const existing = settings.find((setting) => setting.key === key);
    return {
      id: existing?.id ?? 0,
      key,
      group,
      value,
      valueType,
      description: existing?.description || description,
      updatedAt: existing?.updatedAt,
    };
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (warning1 >= warning2 || warning2 >= criticalWarning || criticalWarning >= maxContinuousDriving) {
      showToast("Ngưỡng cảnh báo phải tăng dần và nhỏ hơn giới hạn tối đa.", "warning");
      return;
    }

    setIsSaving(true);
    try {
      const payload: SystemSetting[] = [
        settingOf("driving.max_continuous_minutes", "DRIVING_TIME", String(maxContinuousDriving), "INTEGER", "Thời gian lái liên tục tối đa"),
        settingOf("driving.warn_1_minutes", "DRIVING_TIME", String(warning1), "INTEGER", "Cảnh báo sớm lần 1"),
        settingOf("driving.warn_2_minutes", "DRIVING_TIME", String(warning2), "INTEGER", "Cảnh báo sớm lần 2"),
        settingOf("driving.critical_minutes", "DRIVING_TIME", String(criticalWarning), "INTEGER", "Cảnh báo khẩn trước khi vượt giới hạn"),
        settingOf("ai.drowsiness_enabled", "AI_ALERT", String(aiDrowsyEnabled), "BOOLEAN", "Bật phát hiện ngủ gật"),
        settingOf("ai.phone_usage_enabled", "AI_ALERT", String(aiPhoneEnabled), "BOOLEAN", "Bật phát hiện dùng điện thoại"),
        settingOf("ai.distraction_enabled", "AI_ALERT", String(aiDistractEnabled), "BOOLEAN", "Bật phát hiện mất tập trung"),
        settingOf("ai.speeding_enabled", "AI_ALERT", String(aiSpeedEnabled), "BOOLEAN", "Bật phát hiện vượt tốc độ"),
      ];

      const updated = await Promise.all(payload.map((setting) => safeFleetApi.updateSetting(setting)));
      setSettings((prev) => {
        const merged = new Map(prev.map((setting) => [setting.key, setting]));
        updated.forEach((setting) => merged.set(setting.key, setting));
        return Array.from(merged.values());
      });
      showToast("Đã lưu cấu hình hệ thống.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể lưu cấu hình.", "error");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6 animate-fadeIn pb-6">
      
      {/* ===== Settings title layout ===== */}
      <div className="flex items-center justify-between border-b border-slate-200 dark:border-slate-800 pb-4 flex-shrink-0">
        <div>
          <h3 className="text-lg font-bold text-slate-900 dark:text-white leading-none">
            Cấu hình hệ thống
          </h3>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-1.5">
            Thiết lập ngưỡng cảnh báo, AI và cấu hình server điều hành
          </p>
        </div>

        <button
          onClick={handleSave}
          disabled={isSaving}
          className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-lg shadow-md shadow-blue-500/10 transition cursor-pointer"
        >
          <Save className="w-4 h-4" /> {isSaving ? "Đang lưu..." : "Lưu cấu hình"}
        </button>
      </div>

      {isLoading && (
        <div className="px-4 py-3 rounded-xl bg-blue-50 dark:bg-blue-950/30 border border-blue-100 dark:border-blue-900/50 text-xs font-semibold text-blue-700 dark:text-blue-300">
          Đang tải cấu hình từ backend...
        </div>
      )}

      <form onSubmit={handleSave} className="space-y-6">
        
        {/* Card 1: Time thresholds configuration */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-4">
          <h4 className="font-bold text-xs text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
            <Clock className="w-4.5 h-4.5 text-blue-500" />
            Thời gian lái xe & Ngưỡng cảnh báo lái xe quá giờ
          </h4>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                Thời gian lái liên tục tối đa (phút)
              </label>
              <input
                type="number"
                value={maxContinuousDriving}
                onChange={(e) => setMaxContinuousDriving(parseInt(e.target.value))}
                className="w-full px-3.5 py-2.5 border border-slate-200 dark:border-slate-800 rounded-xl text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none"
              />
            </div>
            
            <div>
              <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                Cảnh báo lần 1 - Nhắc nhở nghỉ ngơi (phút)
              </label>
              <input
                type="number"
                value={warning1}
                onChange={(e) => setWarning1(parseInt(e.target.value))}
                className="w-full px-3.5 py-2.5 border border-slate-200 dark:border-slate-800 rounded-xl text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                Cảnh báo lần 2 - Sắp quá giới hạn (phút)
              </label>
              <input
                type="number"
                value={warning2}
                onChange={(e) => setWarning2(parseInt(e.target.value))}
                className="w-full px-3.5 py-2.5 border border-slate-200 dark:border-slate-800 rounded-xl text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                Cảnh báo khẩn cấp - Yêu cầu dừng xe ngay (phút)
              </label>
              <input
                type="number"
                value={criticalWarning}
                onChange={(e) => setCriticalWarning(parseInt(e.target.value))}
                className="w-full px-3.5 py-2.5 border border-slate-200 dark:border-slate-800 rounded-xl text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none"
              />
            </div>
          </div>
        </div>

        {/* Card 2: AI Settings triggers */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-4">
          <h4 className="font-bold text-xs text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
            <ShieldAlert className="w-4.5 h-4.5 text-amber-500" />
            Cấu hình bộ lọc phát hiện AI
          </h4>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Drowsy filter */}
            <div className="flex items-center justify-between p-3 bg-slate-50/50 dark:bg-slate-800/30 rounded-xl border border-slate-200/50 dark:border-slate-800/50">
              <div>
                <span className="text-xs font-bold text-slate-900 dark:text-white block">Phát hiện ngủ gật</span>
                <span className="text-[10px] text-slate-400">Nhận diện mắt nhắm và đầu cúi lặp lại</span>
              </div>
              <input
                type="checkbox"
                checked={aiDrowsyEnabled}
                onChange={(e) => setAiDrowsyEnabled(e.target.checked)}
                className="w-4.5 h-4.5 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
              />
            </div>

            {/* Phone usage filter */}
            <div className="flex items-center justify-between p-3 bg-slate-50/50 dark:bg-slate-800/30 rounded-xl border border-slate-200/50 dark:border-slate-800/50">
              <div>
                <span className="text-xs font-bold text-slate-900 dark:text-white block">Sử dụng điện thoại</span>
                <span className="text-[10px] text-slate-400">Phát hiện thao tác cầm máy áp lên tai</span>
              </div>
              <input
                type="checkbox"
                checked={aiPhoneEnabled}
                onChange={(e) => setAiPhoneEnabled(e.target.checked)}
                className="w-4.5 h-4.5 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
              />
            </div>

            {/* Distraction filter */}
            <div className="flex items-center justify-between p-3 bg-slate-50/50 dark:bg-slate-800/30 rounded-xl border border-slate-200/50 dark:border-slate-800/50">
              <div>
                <span className="text-xs font-bold text-slate-900 dark:text-white block">Mất tập trung</span>
                <span className="text-[10px] text-slate-400">Quay mặt lệch khỏi hướng lái xe quá 3 giây</span>
              </div>
              <input
                type="checkbox"
                checked={aiDistractEnabled}
                onChange={(e) => setAiDistractEnabled(e.target.checked)}
                className="w-4.5 h-4.5 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
              />
            </div>

            {/* Speeding filter */}
            <div className="flex items-center justify-between p-3 bg-slate-50/50 dark:bg-slate-800/30 rounded-xl border border-slate-200/50 dark:border-slate-800/50">
              <div>
                <span className="text-xs font-bold text-slate-900 dark:text-white block">Vượt quá tốc độ</span>
                <span className="text-[10px] text-slate-400">So sánh vận tốc GPS với giới hạn tuyến</span>
              </div>
              <input
                type="checkbox"
                checked={aiSpeedEnabled}
                onChange={(e) => setAiSpeedEnabled(e.target.checked)}
                className="w-4.5 h-4.5 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
              />
            </div>
          </div>
        </div>

        {/* Card 3: Backend connection settings */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-4">
          <h4 className="font-bold text-xs text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
            <Server className="w-4.5 h-4.5 text-indigo-500" />
            Cấu hình tích hợp Server điều hành
          </h4>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                REST API Endpoint
              </label>
              <input
                type="text"
                value={apiEndpoint}
                onChange={(e) => setApiEndpoint(e.target.value)}
                className="w-full px-3.5 py-2.5 border border-slate-200 dark:border-slate-800 rounded-xl text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white font-mono focus:outline-none"
              />
            </div>
            
            <div>
              <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                WebSocket / Telemetry Stream
              </label>
              <input
                type="text"
                value={wsEndpoint}
                onChange={(e) => setWsEndpoint(e.target.value)}
                className="w-full px-3.5 py-2.5 border border-slate-200 dark:border-slate-800 rounded-xl text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white font-mono focus:outline-none"
              />
            </div>
          </div>
        </div>
      </form>
    </div>
  );
}
