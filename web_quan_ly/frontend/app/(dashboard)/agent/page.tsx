"use client";

import { FormEvent, KeyboardEvent, useEffect, useRef, useState } from "react";
import {
  Bot,
  BookOpenText,
  Database,
  LoaderCircle,
  Route,
  Send,
  ShieldCheck,
  Sparkles,
  Users,
  Wrench,
} from "lucide-react";
import {
  ManagementAgentMessage,
  ManagementAgentResponse,
  safeFleetApi,
} from "@/lib/safeFleetApi";
import { cn } from "@/lib/utils";

type DisplayMessage = ManagementAgentMessage & {
  id: string;
  trace?: ManagementAgentResponse;
  error?: boolean;
};

const SUGGESTIONS = [
  { icon: Database, text: "Cho tôi tổng quan đội xe và các rủi ro cần ưu tiên ngay." },
  { icon: Route, text: "Liệt kê các chuyến đang đi, tài xế, xe và mức rủi ro hiện tại." },
  { icon: Users, text: "Tìm nhóm tài xế điểm an toàn dưới 70 và so sánh trong tháng này." },
  { icon: BookOpenText, text: "Tài xế được hỗ trợ tiền ăn ca thế nào? Trích dẫn đúng điều khoản." },
];

const WELCOME: DisplayMessage = {
  id: "welcome",
  role: "assistant",
  content:
    "Tôi là Agent quản lý SafeFleet. Tôi có thể tra cứu dữ liệu đội xe theo quyền của tài khoản, lập báo cáo ngày/tháng/năm và đối chiếu quy định công ty. Mọi truy vấn hiện ở chế độ chỉ đọc.",
};

function nextId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

export default function ManagementAgentPage() {
  const [messages, setMessages] = useState<DisplayMessage[]>([WELCOME]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [messages, loading]);

  const ask = async (question: string) => {
    const content = question.trim();
    if (!content || loading) return;

    const userMessage: DisplayMessage = { id: nextId(), role: "user", content };
    const nextMessages = [...messages, userMessage];
    setMessages(nextMessages);
    setInput("");
    setLoading(true);

    try {
      const history = nextMessages
        .filter((message) => message.id !== "welcome" && !message.error)
        .slice(-20)
        .map(({ role, content: messageContent }) => ({ role, content: messageContent }));
      const result = await safeFleetApi.managementAgentChat(history);
      setMessages((current) => [
        ...current,
        {
          id: nextId(),
          role: "assistant",
          content: result.responseText,
          trace: result,
        },
      ]);
    } catch (error) {
      setMessages((current) => [
        ...current,
        {
          id: nextId(),
          role: "assistant",
          content: error instanceof Error ? error.message : "Không thể kết nối Agent SafeFleet.",
          error: true,
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    void ask(input);
  };

  const onKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      void ask(input);
    }
  };

  return (
    <div className="grid min-h-[calc(100vh-138px)] gap-5 xl:grid-cols-[minmax(0,1fr)_300px]">
      <section className="sf-surface flex min-h-[680px] min-w-0 flex-col overflow-hidden">
        <header className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--sf-border-card)] px-5 py-4 sm:px-6">
          <div className="flex items-center gap-3">
            <span className="grid h-11 w-11 place-items-center rounded-[15px] bg-[var(--sf-primary-soft)] text-[var(--sf-primary)]">
              <Bot className="h-6 w-6" />
            </span>
            <div>
              <h1 className="text-[16px] font-extrabold tracking-[-0.02em] text-sf-text">
                Agent quản lý SafeFleet
              </h1>
              <p className="mt-0.5 text-[12px] text-sf-text-muted">
                Lập kế hoạch · gọi tool theo quyền · tự kiểm tra sau mỗi bước
              </p>
            </div>
          </div>
          <span className="inline-flex items-center gap-1.5 rounded-full bg-[var(--sf-success-soft)] px-3 py-1.5 text-[11px] font-bold text-[var(--sf-success)]">
            <ShieldCheck className="h-3.5 w-3.5" />
            Chỉ đọc dữ liệu
          </span>
        </header>

        <div className="min-h-0 flex-1 space-y-5 overflow-y-auto px-4 py-5 sm:px-6">
          {messages.map((message) => (
            <article
              key={message.id}
              className={cn("flex", message.role === "user" ? "justify-end" : "justify-start")}
            >
              <div className={cn("max-w-[92%] sm:max-w-[82%]", message.role === "user" && "text-right")}>
                <div
                  className={cn(
                    "inline-block whitespace-pre-wrap rounded-[18px] px-4 py-3 text-left text-[13.5px] leading-6",
                    message.role === "user"
                      ? "rounded-br-[5px] bg-[var(--sf-primary)] text-white"
                      : message.error
                        ? "rounded-bl-[5px] bg-[var(--sf-danger-soft)] text-[var(--sf-danger)]"
                        : "rounded-bl-[5px] border border-[var(--sf-border-card)] bg-[var(--sf-bg-subtle)] text-sf-text"
                  )}
                >
                  {message.content}
                </div>

                {message.trace && (message.trace.plan.length > 0 || message.trace.steps.length > 0) && (
                  <details className="mt-2 overflow-hidden rounded-[14px] border border-[var(--sf-border-card)] bg-[var(--sf-bg-card)] text-left">
                    <summary className="cursor-pointer px-3.5 py-2.5 text-[11.5px] font-bold text-sf-text-secondary">
                      Xem kế hoạch và nhật ký tool ({message.trace.steps.length} bước)
                    </summary>
                    <div className="grid gap-3 border-t border-[var(--sf-border-card)] p-3.5">
                      {message.trace.plan.length > 0 && (
                        <ol className="grid gap-1 text-[11.5px] text-sf-text-muted">
                          {message.trace.plan.map((step, index) => (
                            <li key={`${step}-${index}`}>
                              {index + 1}. {step}
                            </li>
                          ))}
                        </ol>
                      )}
                      {message.trace.steps.map((step) => (
                        <div key={`${step.index}-${step.tool}`} className="rounded-xl bg-[var(--sf-bg-subtle)] p-3">
                          <div className="flex flex-wrap items-center gap-2 text-[11px]">
                            <span className="font-mono font-bold text-[var(--sf-primary)]">{step.tool}</span>
                            <span
                              className={cn(
                                "rounded-full px-2 py-0.5 font-bold",
                                step.planCheck === "DUPLICATE_RESULT_BLOCKED"
                                  ? "bg-[var(--sf-warning-soft)] text-[var(--sf-warning)]"
                                  : step.success
                                    ? "bg-[var(--sf-success-soft)] text-[var(--sf-success)]"
                                    : "bg-[var(--sf-danger-soft)] text-[var(--sf-danger)]"
                              )}
                            >
                              {step.planCheck}
                            </span>
                          </div>
                          <p className="mt-1.5 text-[11px] leading-5 text-sf-text-muted">{step.reason}</p>
                        </div>
                      ))}
                    </div>
                  </details>
                )}
              </div>
            </article>
          ))}

          {loading && (
            <div className="flex items-center gap-2 text-[12.5px] text-sf-text-muted">
              <LoaderCircle className="h-4 w-4 animate-spin text-[var(--sf-primary)]" />
              Agent đang lập kế hoạch và kiểm tra dữ liệu…
            </div>
          )}
          <div ref={bottomRef} />
        </div>

        <form onSubmit={submit} className="border-t border-[var(--sf-border-card)] p-4 sm:p-5">
          <div className="flex items-end gap-2 rounded-[18px] border border-[var(--sf-border-input)] bg-[var(--sf-bg-input)] p-2 focus-within:border-[var(--sf-primary)]">
            <textarea
              value={input}
              onChange={(event) => setInput(event.target.value)}
              onKeyDown={onKeyDown}
              rows={2}
              maxLength={4000}
              disabled={loading}
              placeholder="Hỏi dữ liệu chuyến, nhóm tài xế, báo cáo hoặc điều luật công ty…"
              className="max-h-36 min-h-12 flex-1 resize-none bg-transparent px-2 py-2 text-[13.5px] text-sf-text outline-none placeholder:text-sf-text-muted"
            />
            <button
              type="submit"
              disabled={loading || !input.trim()}
              aria-label="Gửi câu hỏi"
              className="grid h-11 w-11 flex-none place-items-center rounded-[14px] bg-[var(--sf-primary)] text-white transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-45"
            >
              {loading ? <LoaderCircle className="h-5 w-5 animate-spin" /> : <Send className="h-5 w-5" />}
            </button>
          </div>
          <p className="mt-2 text-center text-[10.5px] text-sf-text-muted">
            Enter để gửi · Shift + Enter để xuống dòng · Kết quả cần được đối chiếu trước quyết định quan trọng
          </p>
        </form>
      </section>

      <aside className="grid content-start gap-4">
        <div className="sf-surface p-5">
          <div className="mb-3 flex items-center gap-2 text-[13px] font-extrabold text-sf-text">
            <Sparkles className="h-4 w-4 text-[var(--sf-primary)]" />
            Câu hỏi gợi ý
          </div>
          <div className="grid gap-2">
            {SUGGESTIONS.map(({ icon: Icon, text }) => (
              <button
                key={text}
                type="button"
                disabled={loading}
                onClick={() => void ask(text)}
                className="flex items-start gap-2.5 rounded-[13px] border border-[var(--sf-border-card)] px-3 py-2.5 text-left text-[11.5px] leading-5 text-sf-text-secondary transition hover:border-[var(--sf-primary)] hover:bg-[var(--sf-primary-soft)] disabled:opacity-50"
              >
                <Icon className="mt-0.5 h-4 w-4 flex-none text-[var(--sf-primary)]" />
                {text}
              </button>
            ))}
          </div>
        </div>

        <div className="sf-surface p-5">
          <div className="mb-3 flex items-center gap-2 text-[13px] font-extrabold text-sf-text">
            <Wrench className="h-4 w-4 text-[var(--sf-primary)]" />
            Cơ chế an toàn
          </div>
          <ul className="grid gap-2 text-[11.5px] leading-5 text-sf-text-muted">
            <li>• Tool được cấp theo vai trò đăng nhập.</li>
            <li>• Mỗi kết quả được đánh giá lại với kế hoạch.</li>
            <li>• Kết quả giống hệt quá 2 lần sẽ bị chặn.</li>
            <li>• Quy định công ty phải kèm Điều/Khoản nguồn.</li>
            <li>• Agent quản lý hiện không được ghi trực tiếp vào database.</li>
          </ul>
        </div>
      </aside>
    </div>
  );
}
