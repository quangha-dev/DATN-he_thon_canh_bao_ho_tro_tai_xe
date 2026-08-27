"use client";

import { useEffect, useState } from "react";
import { Bot, CheckCircle2, Clock, Info, KeyRound, PlugZap, Save, Server, ShieldAlert } from "lucide-react";
import { useToast } from "@/context/ToastContext";
import { safeFleetApi, SystemSetting } from "@/lib/safeFleetApi";
import { useAuth } from "@/context/AuthContext";
import { Callout, Skeleton, TextInput } from "@/components/ui";

export default function SettingsPage() {
  const { showToast } = useToast();
  const { user } = useAuth();
  const [settings, setSettings] = useState<SystemSetting[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  const [maxContinuousDriving, setMaxContinuousDriving] = useState(240);
  const [warning1, setWarning1] = useState(180);
  const [warning2, setWarning2] = useState(210);
  const [criticalWarning, setCriticalWarning] = useState(230);

  const [aiDrowsyEnabled, setAiDrowsyEnabled] = useState(true);
  const [aiPhoneEnabled, setAiPhoneEnabled] = useState(true);
  const [aiDistractEnabled, setAiDistractEnabled] = useState(true);
  const [aiSpeedEnabled, setAiSpeedEnabled] = useState(true);

  const [apiEndpoint, setApiEndpoint] = useState("http://localhost:8080/api/v1");
  const [wsEndpoint, setWsEndpoint] = useState("ws://localhost:8080/ws-native");
  const [agentEnabled, setAgentEnabled] = useState(false);
  const [agentApiKey, setAgentApiKey] = useState("");
  const [agentKeyConfigured, setAgentKeyConfigured] = useState(false);
  const [agentKeyHint, setAgentKeyHint] = useState<string | null>(null);
  const [agentMaxSteps, setAgentMaxSteps] = useState(6);
  const [agentSaving, setAgentSaving] = useState(false);
  const [agentTesting, setAgentTesting] = useState(false);

  useEffect(() => {
    let cancelled = false;

    const asInt = (key: string, fallback: number, items: SystemSetting[]) => {
      const value = Number(items.find((s) => s.key === key)?.value);
      return Number.isFinite(value) ? value : fallback;
    };
    const asBool = (key: string, fallback: boolean, items: SystemSetting[]) => {
      const value = items.find((s) => s.key === key)?.value;
      if (value === undefined) return fallback;
      return value === "true";
    };

    const load = async () => {
      setIsLoading(true);
      try {
        const [data, agentConfig] = await Promise.all([
          safeFleetApi.settings(),
          user?.role === "ADMIN" ? safeFleetApi.agentAiConfiguration() : Promise.resolve(null),
        ]);
        if (cancelled) return;
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
        setWsEndpoint(process.env.NEXT_PUBLIC_WS_URL || "ws://localhost:8080/ws-native");
        if (agentConfig) {
          setAgentEnabled(agentConfig.enabled);
          setAgentKeyConfigured(agentConfig.apiKeyConfigured);
          setAgentKeyHint(agentConfig.apiKeyHint ?? null);
          setAgentMaxSteps(agentConfig.maxSteps);
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được cấu hình.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [showToast, user?.role]);

  const saveAgentConfiguration = async () => {
    if (agentEnabled && !agentKeyConfigured && !agentApiKey.trim()) {
      showToast("Hãy nhập OpenAI API key trước khi bật agent.", "warning");
      return;
    }
    setAgentSaving(true);
    try {
      const updated = await safeFleetApi.updateAgentAiConfiguration({
        enabled: agentEnabled,
        apiKey: agentApiKey.trim() || undefined,
        maxSteps: agentMaxSteps,
      });
      setAgentApiKey("");
      setAgentKeyConfigured(updated.apiKeyConfigured);
      setAgentKeyHint(updated.apiKeyHint ?? null);
      setAgentEnabled(updated.enabled);
      showToast("Đã lưu OpenAI key mã hóa trên server.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể lưu cấu hình agent.", "error");
    } finally {
      setAgentSaving(false);
    }
  };

  const testAgentConfiguration = async () => {
    setAgentTesting(true);
    try {
      await safeFleetApi.testAgentAiConfiguration();
      showToast("Kết nối OpenAI gpt-4o-mini thành công.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể kết nối OpenAI.", "error");
    } finally {
      setAgentTesting(false);
    }
  };

  const settingOf = (
    key: string,
    group: SystemSetting["group"],
    value: string,
    valueType: SystemSetting["valueType"],
    description: string
  ): SystemSetting => {
    const existing = settings.find((s) => s.key === key);
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

  const handleSave = async (e?: React.FormEvent) => {
    e?.preventDefault();
    if (
      warning1 >= warning2 ||
      warning2 >= criticalWarning ||
      criticalWarning >= maxContinuousDriving
    ) {
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

      const updated = await Promise.all(payload.map((s) => safeFleetApi.updateSetting(s)));
      setSettings((prev) => {
        const merged = new Map(prev.map((s) => [s.key, s]));
        updated.forEach((s) => merged.set(s.key, s));
        return Array.from(merged.values());
      });
      showToast("Đã lưu cấu hình hệ thống.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể lưu cấu hình.", "error");
    } finally {
      setIsSaving(false);
    }
  };

  /* Đổi phút sang chuỗi "4h00m" như bản thiết kế */
  const asHhmm = (minutes: number) => {
    const safe = Number.isFinite(minutes) ? Math.max(0, minutes) : 0;
    const h = Math.floor(safe / 60);
    const m = safe % 60;
    return `${h}h${String(m).padStart(2, "0")}m`;
  };

  /* Vị trí núm trượt: 240 phút là mốc tối đa của thang, đủ cho mọi cấu hình thật */
  const sliderPct = Math.min(100, Math.max(0, (maxContinuousDriving / 300) * 100));

  /* Bộ lọc AI dựng từ chính các khoá cấu hình backend trả về, không cắt cứng
     bốn mục như bản thiết kế — backend thêm khoá mới là giao diện tự có thêm. */
  const aiToggles: {
    key: string;
    label: string;
    description: string;
    checked: boolean;
    onChange: (v: boolean) => void;
  }[] = [
    {
      key: "ai.drowsiness_enabled",
      label: "Ngủ gật",
      description: "Nhận diện mắt nhắm và đầu cúi lặp lại",
      checked: aiDrowsyEnabled,
      onChange: setAiDrowsyEnabled,
    },
    {
      key: "ai.distraction_enabled",
      label: "Mất tập trung",
      description: "Quay mặt lệch hướng lái quá 3 giây",
      checked: aiDistractEnabled,
      onChange: setAiDistractEnabled,
    },
    {
      key: "ai.phone_usage_enabled",
      label: "Dùng điện thoại",
      description: "Phát hiện thao tác cầm máy áp lên tai",
      checked: aiPhoneEnabled,
      onChange: setAiPhoneEnabled,
    },
    {
      key: "ai.speeding_enabled",
      label: "Vượt tốc độ",
      description: "So sánh vận tốc GPS với giới hạn tuyến",
      checked: aiSpeedEnabled,
      onChange: setAiSpeedEnabled,
    },
  ];

  return (
    <form onSubmit={handleSave} className="grid items-start gap-5 lg:grid-cols-2">
      {/* ============ Cột trái: ngưỡng giờ lái + bộ lọc AI ============ */}
      <div className="sf-surface p-5 sm:p-7">
        <div className="mb-6 flex items-center gap-3">
          <span className="sf-icon-chip">
            <Clock className="h-5 w-5" />
          </span>
          <div>
            <div className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">
              Giới hạn lái liên tục
            </div>
            <div className="mt-0.5 text-[12.5px] text-sf-text-muted">
              Ngưỡng gửi xuống ứng dụng tài xế
            </div>
          </div>
        </div>

        {isLoading ? (
          <div className="grid gap-3">
            <Skeleton className="h-24" />
            <Skeleton className="h-20" />
          </div>
        ) : (
          <div className="grid gap-4">
            {/* Giới hạn tối đa — thanh trượt như bản thiết kế, vẫn ghi vào state cũ */}
            <div
              className="rounded-[var(--sf-r-lg)] border border-[var(--sf-border-card)] p-[18px]"
              style={{ background: "var(--sf-bg-card-alt)" }}
            >
              <div className="flex items-baseline justify-between gap-3">
                <span className="text-[13px] font-semibold text-sf-text">Giới hạn tối đa</span>
                <span className="sf-mono text-[15px]" style={{ color: "var(--sf-primary)" }}>
                  {asHhmm(maxContinuousDriving)}
                </span>
              </div>
              <div className="relative mt-3">
                <div className="sf-track !h-1.5">
                  <span style={{ width: `${sliderPct}%` }} />
                </div>
                <input
                  type="range"
                  min={60}
                  max={300}
                  step={10}
                  value={maxContinuousDriving}
                  onChange={(e) => setMaxContinuousDriving(Number(e.target.value))}
                  aria-label="Giới hạn lái liên tục tối đa (phút)"
                  className="absolute inset-0 m-0 h-full w-full cursor-pointer opacity-0"
                />
                <span
                  aria-hidden
                  className="pointer-events-none absolute top-1/2 h-[18px] w-[18px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[var(--sf-bg-card)]"
                  style={{
                    left: `${sliderPct}%`,
                    boxShadow: "0 2px 8px rgba(20,40,55,.25), 0 0 0 2px #0b8c7f",
                  }}
                />
              </div>
              <p className="mt-3 text-[11.5px] text-sf-text-muted">
                Kéo để đổi mốc tối đa. Ba ngưỡng bên dưới phải tăng dần và nhỏ hơn mốc này.
              </p>
            </div>

            {/* Ba ngưỡng cảnh báo — bản thiết kế vẽ dạng thẻ chỉ đọc,
               ở đây vẫn phải nhập được vì backend lưu từng khoá riêng. */}
            <div className="grid gap-2.5 sm:grid-cols-3">
              <ThresholdTile
                label="Cấp 1 · nhắc nghỉ"
                value={warning1}
                onChange={setWarning1}
                display={asHhmm(warning1)}
              />
              <ThresholdTile
                label="Cấp 2 · gần ngưỡng"
                value={warning2}
                onChange={setWarning2}
                display={asHhmm(warning2)}
                tone="warning"
              />
              <ThresholdTile
                label="Khẩn · dừng xe"
                value={criticalWarning}
                onChange={setCriticalWarning}
                display={asHhmm(criticalWarning)}
                tone="danger"
              />
            </div>
          </div>
        )}

        {/* ---- Bộ lọc cảnh báo AI ---- */}
        <div className="mt-7 border-t border-[var(--sf-border-card)] pt-6">
          <div className="mb-4 flex items-center justify-between gap-3">
            <div className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">
              Bộ lọc cảnh báo AI
            </div>
            <ShieldAlert className="h-[18px] w-[18px] text-sf-text-muted" />
          </div>
          <div className="grid gap-2.5">
            {aiToggles.map((item) => (
              <div
                key={item.key}
                className="flex items-center justify-between gap-4 rounded-[var(--sf-r-md)] border border-[var(--sf-border-card)] px-4 py-3.5"
                style={{ background: "var(--sf-bg-card-alt)" }}
              >
                <div className="min-w-0">
                  <div className="text-[13px] font-medium text-sf-text">{item.label}</div>
                  <div className="mt-0.5 truncate text-[11.5px] text-sf-text-muted">
                    {item.description}
                  </div>
                </div>
                <Toggle checked={item.checked} onChange={item.onChange} label={item.label} />
              </div>
            ))}
          </div>

          <div className="mt-5 flex justify-end">
            <button type="submit" className="sf-pill-primary" disabled={isSaving}>
              <Save className="h-[17px] w-[17px]" />
              {isSaving ? "Đang lưu…" : "Lưu cấu hình"}
            </button>
          </div>
        </div>
      </div>

      {/* ============ Cột phải: kết nối + trợ lý ============ */}
      <div className="grid gap-5">
        <div className="sf-surface p-5 sm:p-7">
          <div className="mb-5 flex items-center gap-3">
            <span
              className="grid h-[38px] w-[38px] flex-none place-items-center rounded-[14px]"
              style={{ background: "var(--sf-bg-inset)", color: "var(--sf-text-secondary)" }}
            >
              <Server className="h-5 w-5" />
            </span>
            <div className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">
              Kết nối hệ thống
            </div>
          </div>

          <div className="grid gap-3">
            <ConnectionRow label="Máy chủ dữ liệu" value={apiEndpoint} mono />
            <ConnectionRow label="Luồng vị trí xe" value={wsEndpoint} mono />
            <ConnectionRow
              label="Trạng thái cấu hình"
              value={
                <span
                  className="inline-flex items-center gap-2 font-semibold"
                  style={{ color: "var(--sf-success)" }}
                >
                  <CheckCircle2 className="h-[17px] w-[17px]" />
                  {settings.length} khoá đang áp dụng
                </span>
              }
            />
          </div>

          <Callout tone="neutral" icon={Info} className="mt-4">
            Hai điểm kết nối trên lấy từ biến môi trường khi triển khai, chỉ hiển thị để đối chiếu.
          </Callout>
        </div>

        {user?.role === "ADMIN" && (
          <div className="sf-surface p-5 sm:p-7">
            <div className="mb-5 flex items-start justify-between gap-4">
              <div className="flex items-center gap-3">
                <span
                  className="grid h-[38px] w-[38px] flex-none place-items-center rounded-[14px]"
                  style={{ background: "var(--sf-accent-soft)", color: "var(--sf-accent-hover)" }}
                >
                  <Bot className="h-5 w-5" />
                </span>
                <div>
                  <div className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">
                    Trợ lý điều hành
                  </div>
                  <div className="mt-0.5 text-[12.5px] text-sf-text-muted">
                    Tóm tắt chuyến và cảnh báo cho tài xế qua gpt-4o-mini
                  </div>
                </div>
              </div>
              <Toggle
                checked={agentEnabled}
                onChange={setAgentEnabled}
                label="Bật trợ lý điều hành"
              />
            </div>

            <div className="grid gap-3">
              <div
                className="rounded-[var(--sf-r-md)] border border-[var(--sf-border-card)] p-4"
                style={{ background: "var(--sf-bg-card-alt)" }}
              >
                <label className="mb-2 block text-[12.5px] font-semibold text-sf-text-secondary">
                  OpenAI API key
                </label>
                <div className="relative">
                  <KeyRound className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-sf-text-muted" />
                  <TextInput
                    type="password"
                    autoComplete="new-password"
                    value={agentApiKey}
                    onChange={(event) => setAgentApiKey(event.target.value)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter") {
                        event.preventDefault();
                        void saveAgentConfiguration();
                      }
                    }}
                    placeholder={agentKeyConfigured ? "Nhập key mới để thay thế" : "sk-..."}
                    className="pl-9"
                  />
                </div>
                <p className="mt-2 text-[11.5px] text-sf-text-muted">
                  {agentKeyConfigured
                    ? `Đã cấu hình: ${agentKeyHint ?? "••••"}. Để trống để giữ nguyên.`
                    : "Key được mã hóa AES-GCM trước khi lưu trên server."}
                </p>
              </div>

              <div
                className="flex items-center justify-between gap-4 rounded-[var(--sf-r-md)] border border-[var(--sf-border-card)] px-4 py-3.5"
                style={{ background: "var(--sf-bg-card-alt)" }}
              >
                <span className="text-[13px] text-sf-text">Giới hạn bước mỗi câu hỏi</span>
                <input
                  type="number"
                  min={2}
                  max={10}
                  value={agentMaxSteps}
                  onChange={(event) => setAgentMaxSteps(Number(event.target.value))}
                  aria-label="Giới hạn bước mỗi câu hỏi"
                  className="sf-mono w-20 rounded-[10px] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] px-2.5 py-1.5 text-right text-[13px] text-sf-text outline-none focus:border-[var(--sf-primary)]"
                />
              </div>
            </div>

            <div className="mt-5 flex gap-2.5">
              <button
                type="button"
                className="sf-pill-ghost flex-1 justify-center"
                disabled={!agentKeyConfigured || agentSaving || agentTesting}
                onClick={() => void testAgentConfiguration()}
              >
                <PlugZap className="h-[17px] w-[17px]" />
                {agentTesting ? "Đang kiểm tra…" : "Chạy thử gợi ý"}
              </button>
              <button
                type="button"
                className="sf-pill-primary flex-1 justify-center"
                disabled={agentSaving || agentTesting}
                onClick={() => void saveAgentConfiguration()}
              >
                <Save className="h-[17px] w-[17px]" />
                {agentSaving ? "Đang lưu…" : "Lưu cấu hình"}
              </button>
            </div>
          </div>
        )}
      </div>
    </form>
  );
}

/** Ô ngưỡng cảnh báo: hiển thị dạng "3h00m" nhưng vẫn nhập được số phút */
function ThresholdTile({
  label,
  value,
  onChange,
  display,
  tone,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  display: string;
  tone?: "warning" | "danger";
}) {
  const bg =
    tone === "warning"
      ? "var(--sf-accent-soft)"
      : tone === "danger"
        ? "var(--sf-danger-soft)"
        : "var(--sf-bg-inset)";
  const fg =
    tone === "warning"
      ? "var(--sf-accent-hover)"
      : tone === "danger"
        ? "var(--sf-danger)"
        : "var(--sf-text-muted)";
  return (
    <label className="block cursor-text rounded-[var(--sf-r-md)] p-4" style={{ background: bg }}>
      <span className="block text-[11.5px]" style={{ color: fg }}>
        {label}
      </span>
      <span className="mt-1.5 flex items-baseline gap-2">
        <input
          type="number"
          min={0}
          step={5}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          className="sf-mono w-14 border-0 bg-transparent p-0 text-[17px] outline-none"
          style={{ color: tone ? fg : "var(--sf-text)" }}
        />
        <span className="text-[11.5px]" style={{ color: fg }}>
          phút · {display}
        </span>
      </span>
    </label>
  );
}

/** Công tắc 46×26 đúng kích thước bản thiết kế */
function Toggle({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={() => onChange(!checked)}
      className="relative h-[26px] w-[46px] flex-none cursor-pointer rounded-full border-0 p-0 transition-colors duration-[var(--sf-dur-base)]"
      style={{
        background: checked ? "#0b8c7f" : "var(--sf-bg-inset-strong, var(--sf-bg-inset))",
      }}
    >
      <span
        className="absolute top-[3px] h-5 w-5 rounded-full bg-white transition-[left] duration-[320ms] ease-[var(--sf-ease-spring)]"
        style={{ left: checked ? 23 : 3, boxShadow: "0 2px 6px rgba(20,40,55,.28)" }}
      />
    </button>
  );
}

/** Dòng trạng thái kết nối trong thẻ "Kết nối hệ thống" */
function ConnectionRow({
  label,
  value,
  mono,
}: {
  label: string;
  value: React.ReactNode;
  mono?: boolean;
}) {
  return (
    <div
      className="flex items-center justify-between gap-3 rounded-[15px] px-4 py-3.5"
      style={{ background: "var(--sf-bg-inset)" }}
    >
      <span className="flex-none text-[13px] text-sf-text-secondary">{label}</span>
      <span
        className={`min-w-0 truncate text-right text-[12.5px] text-sf-text ${mono ? "sf-mono" : ""}`}
      >
        {value}
      </span>
    </div>
  );
}
