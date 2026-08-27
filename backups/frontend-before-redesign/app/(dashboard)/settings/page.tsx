"use client";

import { useEffect, useState } from "react";
import { Bot, CheckCircle2, Clock, KeyRound, ShieldAlert, Server, Save, Info, PlugZap } from "lucide-react";
import { useToast } from "@/context/ToastContext";
import { safeFleetApi, SystemSetting } from "@/lib/safeFleetApi";
import { useAuth } from "@/context/AuthContext";
import {
  Button,
  Callout,
  Card,
  CardHeader,
  Field,
  Reveal,
  SectionTitle,
  Skeleton,
  Switch,
  TextInput,
} from "@/components/ui";

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

  return (
    <form onSubmit={handleSave} className="mx-auto max-w-4xl space-y-5 pb-6">
      {/* ===== Tiêu đề ===== */}
      <Card padding="sm">
        <SectionTitle
          eyebrow="Hệ thống"
          title="Cấu hình vận hành"
          description="Ngưỡng cảnh báo giờ lái, bộ lọc AI và điểm kết nối backend."
          action={
            <Button type="submit" icon={Save} size="sm" loading={isSaving}>
              Lưu cấu hình
            </Button>
          }
        />
      </Card>

      {isLoading && (
        <div className="grid gap-3 sm:grid-cols-2">
          <Skeleton className="h-24" />
          <Skeleton className="h-24" />
        </div>
      )}

      {/* ===== Ngưỡng giờ lái ===== */}
      <Reveal>
        <Card padding="lg">
          <CardHeader
            title="Thời gian lái & ngưỡng cảnh báo"
            subtitle="Các mốc phải tăng dần và nhỏ hơn giới hạn tối đa"
            icon={Clock}
          />
          <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2">
            <Field label="Thời gian lái liên tục tối đa (phút)" hint="Vượt mốc này sẽ chặn chuyến">
              <TextInput
                type="number"
                value={maxContinuousDriving}
                onChange={(e) => setMaxContinuousDriving(Number(e.target.value))}
              />
            </Field>
            <Field label="Cảnh báo lần 1 — nhắc nghỉ ngơi (phút)">
              <TextInput
                type="number"
                value={warning1}
                onChange={(e) => setWarning1(Number(e.target.value))}
              />
            </Field>
            <Field label="Cảnh báo lần 2 — sắp quá giới hạn (phút)">
              <TextInput
                type="number"
                value={warning2}
                onChange={(e) => setWarning2(Number(e.target.value))}
              />
            </Field>
            <Field label="Cảnh báo khẩn — yêu cầu dừng xe (phút)">
              <TextInput
                type="number"
                value={criticalWarning}
                onChange={(e) => setCriticalWarning(Number(e.target.value))}
              />
            </Field>
          </div>

          <Callout tone="accent" icon={Info} className="mt-4">
            Thứ tự bắt buộc: lần 1 &lt; lần 2 &lt; khẩn cấp &lt; giới hạn tối đa.
          </Callout>
        </Card>
      </Reveal>

      {/* ===== Bộ lọc AI ===== */}
      <Reveal delay={60}>
        <Card padding="lg">
          <CardHeader
            title="Bộ lọc phát hiện AI"
            subtitle="Bật/tắt từng loại sự kiện mô hình gửi về"
            icon={ShieldAlert}
          />
          <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-2">
            <Switch
              checked={aiDrowsyEnabled}
              onChange={setAiDrowsyEnabled}
              label="Phát hiện ngủ gật"
              description="Nhận diện mắt nhắm và đầu cúi lặp lại"
            />
            <Switch
              checked={aiPhoneEnabled}
              onChange={setAiPhoneEnabled}
              label="Sử dụng điện thoại"
              description="Phát hiện thao tác cầm máy áp lên tai"
            />
            <Switch
              checked={aiDistractEnabled}
              onChange={setAiDistractEnabled}
              label="Mất tập trung"
              description="Quay mặt lệch hướng lái quá 3 giây"
            />
            <Switch
              checked={aiSpeedEnabled}
              onChange={setAiSpeedEnabled}
              label="Vượt quá tốc độ"
              description="So sánh vận tốc GPS với giới hạn tuyến"
            />
          </div>
        </Card>
      </Reveal>

      {/* ===== Kết nối backend ===== */}
      <Reveal delay={120}>
        <Card padding="lg">
          <CardHeader
            title="Kết nối server điều hành"
            subtitle="Chỉ đọc — thay đổi qua biến môi trường khi triển khai"
            icon={Server}
          />
          <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2">
            <Field label="REST API endpoint">
              <TextInput
                mono
                value={apiEndpoint}
                onChange={(e) => setApiEndpoint(e.target.value)}
              />
            </Field>
            <Field label="WebSocket / telemetry stream">
              <TextInput mono value={wsEndpoint} onChange={(e) => setWsEndpoint(e.target.value)} />
            </Field>
          </div>
        </Card>
      </Reveal>

      {user?.role === "ADMIN" && (
        <Reveal delay={180}>
          <Card padding="lg">
            <CardHeader
              title="Agent dữ liệu · OpenAI"
              subtitle="Toàn bộ lập kế hoạch, gọi tool và kiểm tra kết quả chạy trên backend"
              icon={Bot}
            />
            <div className="mt-4 space-y-4">
              <Switch
                checked={agentEnabled}
                onChange={setAgentEnabled}
                label="Bật agent gpt-4o-mini"
                description="Điện thoại chỉ gửi câu hỏi và nhận câu trả lời cuối cùng từ server"
              />

              <div className="grid grid-cols-1 gap-4 md:grid-cols-[1fr_180px]">
                <Field
                  label="OpenAI API key"
                  hint={agentKeyConfigured ? `Đã cấu hình: ${agentKeyHint ?? "••••"}. Để trống để giữ nguyên.` : "Key được mã hóa AES-GCM trước khi lưu."}
                >
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
                </Field>
                <Field label="Giới hạn bước" hint="2–10 bước/tool cho mỗi câu hỏi">
                  <TextInput
                    type="number"
                    min={2}
                    max={10}
                    value={agentMaxSteps}
                    onChange={(event) => setAgentMaxSteps(Number(event.target.value))}
                  />
                </Field>
              </div>

              <Callout tone="accent" icon={CheckCircle2}>
                Tool hiện có: chuyến đã đi, chuyến chưa đi, chuyến đang chạy, chi tiết chuyến và báo cáo tháng. Mỗi tool chỉ đọc dữ liệu của tài xế đang đăng nhập.
              </Callout>

              <div className="flex flex-wrap justify-end gap-2">
                <Button
                  type="button"
                  variant="outline"
                  icon={PlugZap}
                  loading={agentTesting}
                  disabled={!agentKeyConfigured || agentSaving}
                  onClick={() => void testAgentConfiguration()}
                >
                  Kiểm tra kết nối
                </Button>
                <Button
                  type="button"
                  icon={Save}
                  loading={agentSaving}
                  disabled={agentTesting}
                  onClick={() => void saveAgentConfiguration()}
                >
                  Lưu cấu hình agent
                </Button>
              </div>
            </div>
          </Card>
        </Reveal>
      )}
    </form>
  );
}
