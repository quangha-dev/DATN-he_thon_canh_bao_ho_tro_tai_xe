"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  ReactNode,
} from "react";
import { useRouter, usePathname } from "next/navigation";
import { AuthUser } from "@/types";
import { safeFleetApi, userFromAuth, userFromCurrent } from "@/lib/safeFleetApi";
import { defaultPathForRole } from "@/lib/accessControl";

// =============================================================================
// TYPES
// =============================================================================
interface AuthContextType {
  user: AuthUser | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
  hasRole: (roles: string[]) => boolean;
}

const PUBLIC_ROUTES = ["/login", "/forgot-password"];

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// =============================================================================
// PROVIDER
// =============================================================================
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();
  const pathname = usePathname();

  // --- Restore session on mount ---
  useEffect(() => {
    let cancelled = false;

    const initAuth = async () => {
      try {
        const savedUser = localStorage.getItem("user");
        const token = localStorage.getItem("accessToken");
        if (!token) {
          return;
        }

        if (savedUser) {
          setUser(JSON.parse(savedUser));
        }

        const currentUser = userFromCurrent(await safeFleetApi.me());
        if (!cancelled) {
          localStorage.setItem("user", JSON.stringify(currentUser));
          setUser(currentUser);
        }
      } catch {
        localStorage.removeItem("user");
        localStorage.removeItem("accessToken");
        localStorage.removeItem("refreshToken");
        if (!cancelled) setUser(null);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    initAuth();

    return () => {
      cancelled = true;
    };
  }, []);

  // --- Route guard ---
  useEffect(() => {
    if (isLoading) return;

    const isPublic = PUBLIC_ROUTES.some((r) => pathname.startsWith(r));

    if (!user && !isPublic) {
      router.push("/login");
    }
    if (user && (isPublic || pathname === "/")) {
      router.push(defaultPathForRole(user.role));
    }
  }, [user, pathname, isLoading, router]);

  // --- Login ---
  const login = useCallback(
    async (username: string, password: string) => {
      setIsLoading(true);
      try {
        const auth = await safeFleetApi.login(username.trim(), password);
        const userData = userFromAuth(auth);

        localStorage.setItem("accessToken", auth.accessToken);
        localStorage.setItem("refreshToken", auth.refreshToken);
        localStorage.setItem("user", JSON.stringify(userData));
        setUser(userData);
        router.push(defaultPathForRole(userData.role));
      } finally {
        setIsLoading(false);
      }
    },
    [router]
  );

  // --- Logout ---
  const logout = useCallback(() => {
    const refreshToken = localStorage.getItem("refreshToken");
    if (refreshToken) {
      void safeFleetApi.logout(refreshToken).catch(() => undefined);
    }
    localStorage.removeItem("accessToken");
    localStorage.removeItem("refreshToken");
    localStorage.removeItem("user");
    setUser(null);
    router.push("/login");
  }, [router]);

  // --- Check role ---
  const hasRole = useCallback(
    (roles: string[]) => {
      if (!user) return false;
      return roles.includes(user.role);
    },
    [user]
  );

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isAuthenticated: !!user,
        login,
        logout,
        hasRole,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used within AuthProvider");
  return context;
}
