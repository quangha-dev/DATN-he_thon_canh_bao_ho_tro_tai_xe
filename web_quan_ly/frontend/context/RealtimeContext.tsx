"use client";

import {
  createContext,
  ReactNode,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { useAuth } from "@/context/AuthContext";
import { UserRole } from "@/types";

export type RealtimeStatus = "disconnected" | "connecting" | "connected";

interface RealtimeContextValue {
  status: RealtimeStatus;
}

const RealtimeContext = createContext<RealtimeContextValue>({
  status: "disconnected",
});

const BACK_OFFICE_TOPICS = [
  "/topic/vehicles/positions",
  "/topic/safety-events",
  "/topic/incidents",
  "/topic/flood-reports",
  "/topic/notifications",
];

function topicsForRole(role?: UserRole): string[] {
  if (role === "RESCUE_TEAM") return ["/topic/incidents"];
  if (["ADMIN", "FLEET_MANAGER", "DISPATCHER", "SAFETY_OFFICER"].includes(role ?? "")) {
    return BACK_OFFICE_TOPICS;
  }
  return [];
}

function websocketUrl() {
  const configured = process.env.NEXT_PUBLIC_WS_URL?.trim();
  if (configured) return configured;
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const isLocalDevelopment = ["localhost", "127.0.0.1"].includes(
    window.location.hostname
  );
  if (isLocalDevelopment && window.location.port !== "8080") {
    const backendPort = process.env.NEXT_PUBLIC_BACKEND_PORT || "8080";
    return `${protocol}//${window.location.hostname}:${backendPort}/ws-native`;
  }
  return `${protocol}//${window.location.host}/ws-native`;
}

function stompFrame(command: string, headers: Record<string, string> = {}, body = "") {
  const headerLines = Object.entries(headers).map(([key, value]) => `${key}:${value}`);
  return `${command}\n${headerLines.join("\n")}\n\n${body}\0`;
}

function parseFrame(frame: string) {
  const normalized = frame.replace(/^\n+/, "");
  const divider = normalized.indexOf("\n\n");
  const head = divider >= 0 ? normalized.slice(0, divider) : normalized;
  const body = divider >= 0 ? normalized.slice(divider + 2) : "";
  const lines = head.split("\n");
  const command = lines.shift() || "";
  const headers = Object.fromEntries(
    lines
      .map((line) => {
        const separator = line.indexOf(":");
        return separator < 0
          ? [line, ""]
          : [line.slice(0, separator), line.slice(separator + 1)];
      })
      .filter(([key]) => key)
  );
  return { command, headers, body };
}

export function RealtimeProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated, user } = useAuth();
  const [status, setStatus] = useState<RealtimeStatus>("disconnected");
  const retryRef = useRef(0);

  useEffect(() => {
    if (!isAuthenticated) {
      setStatus("disconnected");
      return;
    }

    let active = true;
    let socket: WebSocket | null = null;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
    let buffer = "";

    const connect = () => {
      if (!active) return;
      const token = localStorage.getItem("accessToken");
      if (!token) {
        setStatus("disconnected");
        return;
      }

      setStatus("connecting");
      socket = new WebSocket(websocketUrl());

      socket.onopen = () => {
        socket?.send(
          stompFrame("CONNECT", {
            "accept-version": "1.2",
            "heart-beat": "0,0",
            Authorization: `Bearer ${token}`,
          })
        );
      };

      socket.onmessage = (event) => {
        buffer += String(event.data);
        const frames = buffer.split("\0");
        buffer = frames.pop() || "";
        for (const rawFrame of frames) {
          const frame = parseFrame(rawFrame);
          if (frame.command === "CONNECTED") {
            retryRef.current = 0;
            setStatus("connected");
            topicsForRole(user?.role).forEach((destination, index) => {
              socket?.send(
                stompFrame("SUBSCRIBE", {
                  id: `safefleet-${index}`,
                  destination,
                  ack: "auto",
                })
              );
            });
          }
          if (frame.command === "MESSAGE") {
            let payload: unknown = frame.body;
            try {
              payload = JSON.parse(frame.body);
            } catch {
              // Keep non-JSON messages observable for diagnostics.
            }
            window.dispatchEvent(
              new CustomEvent("safefleet:realtime", {
                detail: {
                  destination: frame.headers.destination,
                  payload,
                },
              })
            );
          }
          if (frame.command === "ERROR") {
            socket?.close(4001, "STOMP error");
          }
        }
      };

      socket.onerror = () => socket?.close();
      socket.onclose = () => {
        if (!active) return;
        setStatus("disconnected");
        const delay = Math.min(30_000, 1_000 * 2 ** retryRef.current);
        retryRef.current += 1;
        reconnectTimer = setTimeout(connect, delay);
      };
    };

    connect();
    return () => {
      active = false;
      if (reconnectTimer) clearTimeout(reconnectTimer);
      if (socket?.readyState === WebSocket.OPEN) {
        socket.send(stompFrame("DISCONNECT", { receipt: "close" }));
      }
      socket?.close();
    };
  }, [isAuthenticated, user?.role]);

  return (
    <RealtimeContext.Provider value={{ status }}>
      {children}
    </RealtimeContext.Provider>
  );
}

export function useRealtime() {
  return useContext(RealtimeContext);
}
