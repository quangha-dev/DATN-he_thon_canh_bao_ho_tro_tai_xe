import { UserRole } from "@/types";

const MANAGER_ROLES: UserRole[] = ["ADMIN", "FLEET_MANAGER"];
const OPERATIONS_ROLES: UserRole[] = ["ADMIN", "FLEET_MANAGER", "DISPATCHER"];
const SAFETY_ROLES: UserRole[] = ["ADMIN", "FLEET_MANAGER", "DISPATCHER", "SAFETY_OFFICER"];
const INCIDENT_ROLES: UserRole[] = ["ADMIN", "FLEET_MANAGER", "DISPATCHER", "SAFETY_OFFICER", "RESCUE_TEAM"];
const DRIVER_VISIBLE_ROLES: UserRole[] = ["ADMIN", "FLEET_MANAGER", "DISPATCHER", "SAFETY_OFFICER", "DRIVER"];

const ROUTE_ACCESS: Record<string, UserRole[]> = {
  "/command-center": SAFETY_ROLES,
  "/realtime-map": SAFETY_ROLES,
  "/dispatch": OPERATIONS_ROLES,
  "/trips": DRIVER_VISIBLE_ROLES,
  "/vehicles": SAFETY_ROLES,
  "/drivers": SAFETY_ROLES,
  "/devices": OPERATIONS_ROLES,
  "/maintenance": OPERATIONS_ROLES,
  "/alerts": DRIVER_VISIBLE_ROLES,
  "/incidents": INCIDENT_ROLES,
  "/flood-map": SAFETY_ROLES,
  "/reports": INCIDENT_ROLES,
  "/accounts": MANAGER_ROLES,
  "/settings": MANAGER_ROLES,
};

export function defaultPathForRole(role: UserRole): string {
  if (role === "DRIVER") return "/trips";
  if (role === "RESCUE_TEAM") return "/incidents";
  return "/command-center";
}

export function canAccessPath(role: UserRole, pathname: string): boolean {
  const matchedPath = Object.keys(ROUTE_ACCESS)
    .sort((a, b) => b.length - a.length)
    .find((path) => pathname === path || pathname.startsWith(`${path}/`));

  if (!matchedPath) return true;
  return ROUTE_ACCESS[matchedPath].includes(role);
}
