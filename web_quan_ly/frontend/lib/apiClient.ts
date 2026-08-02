"use client";

import axios, { AxiosError, AxiosResponse, InternalAxiosRequestConfig } from "axios";

// =============================================================================
// 1. CONFIGURATION
// =============================================================================

const BASE_URL = process.env.NEXT_PUBLIC_API_URL || "/api/v1";

const apiClient = axios.create({
  baseURL: BASE_URL,
  headers: { "Content-Type": "application/json" },
  timeout: 15000,
});

let refreshPromise: Promise<string> | null = null;

const forceLogout = () => {
  if (typeof window !== "undefined") {
    localStorage.removeItem("accessToken");
    localStorage.removeItem("refreshToken");
    localStorage.removeItem("user");
    if (window.location.pathname !== "/login") {
      window.location.href = "/login";
    }
  }
};

// =============================================================================
// 3. REQUEST INTERCEPTOR — Gắn JWT Token
// =============================================================================

apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    if (typeof window !== "undefined") {
      const token = localStorage.getItem("accessToken");
      if (token && config.headers) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// =============================================================================
// 4. RESPONSE INTERCEPTOR — Xử lý lỗi mềm từ backend
// =============================================================================

apiClient.interceptors.response.use(
  (response: AxiosResponse) => response,
  async (error: AxiosError) => {
    if (!error.response) {
      return Promise.reject(new Error("Lỗi kết nối mạng. Vui lòng kiểm tra lại."));
    }

    const { status } = error.response;
    const errorData = error.response.data as Record<string, unknown> | string | undefined;
    const backendMessage =
      typeof errorData === "object" && errorData !== null
        ? (errorData.message as string | undefined)
        : typeof errorData === "string"
          ? errorData
          : undefined;

    const originalRequest = error.config as
      | (InternalAxiosRequestConfig & { _retry?: boolean })
      | undefined;
    if (
      status === 401 &&
      originalRequest &&
      !originalRequest._retry &&
      !originalRequest.url?.includes("/auth/")
    ) {
      const refreshToken =
        typeof window !== "undefined" ? localStorage.getItem("refreshToken") : null;
      if (refreshToken) {
        originalRequest._retry = true;
        try {
          refreshPromise ??= axios
            .post<{
              data: { accessToken: string; refreshToken: string };
            }>(`${BASE_URL}/auth/refresh`, { refreshToken })
            .then((response) => {
              localStorage.setItem("accessToken", response.data.data.accessToken);
              localStorage.setItem("refreshToken", response.data.data.refreshToken);
              return response.data.data.accessToken;
            })
            .finally(() => {
              refreshPromise = null;
            });
          const accessToken = await refreshPromise;
          originalRequest.headers.Authorization = `Bearer ${accessToken}`;
          return apiClient(originalRequest);
        } catch {
          forceLogout();
          return Promise.reject(new Error("Phiên đăng nhập đã hết hạn."));
        }
      }
    }

    if (status === 401) {
      forceLogout();
      return Promise.reject(new Error(backendMessage || "Phiên đăng nhập đã hết hạn."));
    }

    if (status === 403) {
      return Promise.reject(new Error(backendMessage || "Bạn không có quyền thực hiện thao tác này."));
    }

    return Promise.reject(new Error(backendMessage || "Có lỗi xảy ra. Vui lòng thử lại."));
  }
);

export default apiClient;
