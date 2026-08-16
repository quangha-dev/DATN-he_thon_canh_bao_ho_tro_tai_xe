"use client";

import { useEffect, useRef, useState } from "react";
import { MAP_CONFIG } from "@/lib/utils";
import { Vehicle, FloodPoint, Incident } from "@/types";
import { cn } from "@/lib/utils";

/** Lớp bố cục chung cho mọi marker — màu sắc gán riêng bằng CSS variable. */
const MARKER_BASE =
  "relative w-8 h-8 rounded-full border-2 flex items-center justify-center cursor-pointer " +
  "shadow-[var(--sf-shadow-md)] transition-transform duration-200 ease-[var(--sf-ease-spring)] hover:scale-110";

const VEHICLE_MARKER_COLOR: Record<string, string> = {
  running: "var(--sf-primary)",
  idle: "var(--sf-success)",
  maintenance: "var(--sf-warning)",
  offline: "var(--sf-neutral)",
};

const FLOOD_MARKER_COLOR: Record<string, string> = {
  light: "var(--sf-info)",
  moderate: "var(--sf-warning)",
  heavy: "var(--sf-warning)",
  impassable: "var(--sf-danger)",
};

interface MapViewProps {
  vehicles?: Vehicle[];
  floodPoints?: FloodPoint[];
  incidents?: Incident[];
  routeCoordinates?: [number, number][];
  routeStart?: { lat: number; lng: number; label?: string } | null;
  routeEnd?: { lat: number; lng: number; label?: string } | null;
  onVehicleClick?: (vehicle: Vehicle) => void;
  onFloodPointClick?: (floodPoint: FloodPoint) => void;
  onIncidentClick?: (incident: Incident) => void;
  selectedVehicleId?: string | null;
  interactive?: boolean;
}

export default function MapView({
  vehicles = [],
  floodPoints = [],
  incidents = [],
  routeCoordinates = [],
  routeStart = null,
  routeEnd = null,
  onVehicleClick,
  onFloodPointClick,
  onIncidentClick,
  selectedVehicleId,
  interactive = true,
}: MapViewProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<any>(null);
  const markersRef = useRef<Record<string, any>>({});
  const routeMarkersRef = useRef<Record<string, any>>({});
  const [mapLoaded, setMapLoaded] = useState(false);

  // Initialize Map
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    // Dynamically import MapLibre GL
    import("maplibre-gl").then((maplibregl) => {
      if (!mapContainerRef.current) return;

      const map = new maplibregl.Map({
        container: mapContainerRef.current,
        style: {
          version: 8,
          sources: {
            "osm-tiles": {
              type: "raster",
              tiles: [MAP_CONFIG.tileUrl],
              tileSize: 256,
              attribution: MAP_CONFIG.attribution,
            },
          },
          layers: [
            {
              id: "osm-layer",
              type: "raster",
              source: "osm-tiles",
              minzoom: 0,
              maxzoom: 19,
            },
          ],
        },
        center: MAP_CONFIG.center,
        zoom: MAP_CONFIG.zoom,
        interactive: interactive,
      });

      if (interactive) {
        map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");
      }

      map.on("load", () => {
        mapRef.current = map;
        setMapLoaded(true);
      });
    });

    return () => {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, [interactive]);

  // Update Markers when data changes
  useEffect(() => {
    if (!mapLoaded || !mapRef.current) return;

    import("maplibre-gl").then((maplibregl) => {
      // Clear old markers that are no longer present
      const currentIds = new Set([
        ...vehicles.filter((v) => v.lat !== null && v.lng !== null).map((v) => `vehicle-${v.id}`),
        ...floodPoints.map((f) => `flood-${f.id}`),
        ...incidents.map((i) => `incident-${i.id}`),
      ]);

      Object.keys(markersRef.current).forEach((id) => {
        if (!currentIds.has(id)) {
          markersRef.current[id].remove();
          delete markersRef.current[id];
        }
      });

      // 1. Render Vehicle Markers
      vehicles.forEach((vehicle) => {
        const id = `vehicle-${vehicle.id}`;
        if (vehicle.lat === null || vehicle.lng === null) {
          markersRef.current[id]?.remove();
          delete markersRef.current[id];
          return;
        }
        const isSelected = selectedVehicleId === vehicle.id;

        // Custom Marker Element — màu lấy từ token, không hardcode
        const el = document.createElement("div");
        el.className = cn(MARKER_BASE, isSelected ? "scale-110 z-30" : "z-10");
        el.style.background = VEHICLE_MARKER_COLOR[vehicle.status] ?? "var(--sf-neutral)";
        el.style.color = "#ffffff";
        el.style.borderColor = "var(--sf-bg-card)";
        if (isSelected) {
          el.style.boxShadow = "0 0 0 4px rgba(var(--sf-primary-rgb), 0.42), var(--sf-shadow-md)";
        }

        // Icon inside marker
        const iconEl = document.createElement("div");
        iconEl.innerHTML = `<svg viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="3" width="15" height="13"></rect><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"></polygon><circle cx="5.5" cy="18.5" r="2.5"></circle><circle cx="18.5" cy="18.5" r="2.5"></circle></svg>`;
        el.appendChild(iconEl);

        // Chấm cảnh báo
        if (vehicle.totalAlerts > 0 && vehicle.status !== "offline") {
          const badge = document.createElement("span");
          badge.className =
            "absolute -top-1 -right-1 w-3 h-3 rounded-full border-2 animate-sf-pulse-dot";
          badge.style.background = "var(--sf-danger)";
          badge.style.borderColor = "var(--sf-bg-card)";
          el.appendChild(badge);
        }

        el.addEventListener("click", () => {
          if (onVehicleClick) onVehicleClick(vehicle);
        });

        // Add or update marker
        if (markersRef.current[id]) {
          const existing = markersRef.current[id];
          existing.setLngLat([vehicle.lng, vehicle.lat]);
          const node = existing.getElement() as HTMLElement;
          node.className = el.className;
          node.style.background = el.style.background;
          node.style.boxShadow = el.style.boxShadow;
        } else {
          const marker = new maplibregl.Marker({ element: el })
            .setLngLat([vehicle.lng, vehicle.lat])
            .addTo(mapRef.current);
          markersRef.current[id] = marker;
        }
      });

      // 2. Render Flood Point Markers
      floodPoints.forEach((point) => {
        const id = `flood-${point.id}`;

        const el = document.createElement("div");
        el.className = cn(
          MARKER_BASE,
          "z-20",
          point.severity === "impassable" && "animate-sf-pulse-ring"
        );
        el.style.background = FLOOD_MARKER_COLOR[point.severity] ?? "var(--sf-primary)";
        el.style.color = "#ffffff";
        el.style.borderColor = "var(--sf-bg-card)";

        const iconEl = document.createElement("div");
        iconEl.innerHTML = `<svg viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22a7 7 0 0 0 5-5.28M17.75 7L14 3.25M12 2a7 7 0 0 0-7 7c0 5.25 7 13 7 13s7-7.75 7-13a7 7 0 0 0-7-7z"></path></svg>`;
        el.appendChild(iconEl);

        el.addEventListener("click", () => {
          if (onFloodPointClick) onFloodPointClick(point);
        });

        if (markersRef.current[id]) {
          markersRef.current[id].setLngLat([point.lng, point.lat]);
        } else {
          const marker = new maplibregl.Marker({ element: el })
            .setLngLat([point.lng, point.lat])
            .addTo(mapRef.current);
          markersRef.current[id] = marker;
        }
      });

      // 3. Render Incident Markers (SOS)
      incidents.forEach((incident) => {
        const id = `incident-${incident.id}`;

        const el = document.createElement("div");
        el.className = cn(MARKER_BASE, "w-9 h-9 z-40 animate-sf-pulse-ring");
        el.style.background = "var(--sf-danger)";
        el.style.color = "#ffffff";
        el.style.borderColor = "var(--sf-bg-card)";

        const iconEl = document.createElement("div");
        iconEl.innerHTML = `<svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>`;
        el.appendChild(iconEl);

        el.addEventListener("click", () => {
          if (onIncidentClick) onIncidentClick(incident);
        });

        if (markersRef.current[id]) {
          markersRef.current[id].setLngLat([incident.lng, incident.lat]);
        } else {
          const marker = new maplibregl.Marker({ element: el })
            .setLngLat([incident.lng, incident.lat])
            .addTo(mapRef.current);
          markersRef.current[id] = marker;
        }
      });
    });
  }, [vehicles, floodPoints, incidents, mapLoaded, selectedVehicleId, onVehicleClick, onFloodPointClick, onIncidentClick]);

  // Render route preview line and origin/destination markers.
  useEffect(() => {
    if (!mapLoaded || !mapRef.current) return;

    import("maplibre-gl").then((maplibregl) => {
      const map = mapRef.current;
      const sourceId = "dispatch-route-source";
      const lineLayerId = "dispatch-route-line";
      const outlineLayerId = "dispatch-route-outline";
      const hasRoute = routeCoordinates.length >= 2;

      const routeData = {
        type: "Feature",
        properties: {},
        geometry: {
          type: "LineString",
          coordinates: hasRoute ? routeCoordinates : [],
        },
      };

      if (!map.getSource(sourceId)) {
        map.addSource(sourceId, {
          type: "geojson",
          data: routeData,
        });
      } else {
        map.getSource(sourceId).setData(routeData);
      }

      if (!map.getLayer(outlineLayerId)) {
        map.addLayer({
          id: outlineLayerId,
          type: "line",
          source: sourceId,
          paint: {
            "line-color": "#ffffff",
            "line-width": 8,
            "line-opacity": 0.92,
          },
          layout: {
            "line-cap": "round",
            "line-join": "round",
          },
        });
      }

      if (!map.getLayer(lineLayerId)) {
        map.addLayer({
          id: lineLayerId,
          type: "line",
          source: sourceId,
          paint: {
            "line-color": "#087f73",
            "line-width": 4,
            "line-opacity": 0.95,
          },
          layout: {
            "line-cap": "round",
            "line-join": "round",
          },
        });
      }

      const syncRouteMarker = (
        id: "start" | "end",
        point: { lat: number; lng: number; label?: string } | null,
        label: string,
        className: string,
        background: string
      ) => {
        if (!point) {
          routeMarkersRef.current[id]?.remove();
          delete routeMarkersRef.current[id];
          return;
        }

        if (routeMarkersRef.current[id]) {
          routeMarkersRef.current[id].setLngLat([point.lng, point.lat]);
          return;
        }

        const el = document.createElement("div");
        el.className = "flex flex-col items-center gap-1";
        const dot = document.createElement("div");
        dot.className = className;
        dot.style.background = background;
        dot.style.borderColor = "var(--sf-bg-card)";
        dot.textContent = label;
        el.appendChild(dot);

        const marker = new maplibregl.Marker({ element: el, anchor: "center" })
          .setLngLat([point.lng, point.lat])
          .addTo(map);
        routeMarkersRef.current[id] = marker;
      };

      const routePinBase =
        "w-7 h-7 rounded-full text-white border-2 shadow-[var(--sf-shadow-lg)] flex items-center justify-center text-[12.5px] font-extrabold";
      syncRouteMarker("start", routeStart, "A", routePinBase, "var(--sf-primary)");
      syncRouteMarker("end", routeEnd, "B", routePinBase, "var(--sf-accent-600)");

      if (hasRoute) {
        const bounds = new maplibregl.LngLatBounds(routeCoordinates[0], routeCoordinates[0]);
        routeCoordinates.forEach((coordinate) => bounds.extend(coordinate));
        map.fitBounds(bounds, { padding: 54, duration: 700, maxZoom: 14 });
      }
    });
  }, [mapLoaded, routeCoordinates, routeStart, routeEnd]);

  // Center map on selected vehicle
  useEffect(() => {
    if (!mapLoaded || !mapRef.current || !selectedVehicleId) return;

    const selectedVehicle = vehicles.find((v) => v.id === selectedVehicleId);
    if (selectedVehicle) {
      mapRef.current.easeTo({
        center: [selectedVehicle.lng, selectedVehicle.lat],
        zoom: 14,
        duration: 800,
      });
    }
  }, [selectedVehicleId, vehicles, mapLoaded]);

  return (
    <div className="relative w-full h-full min-h-[300px]">
      <div ref={mapContainerRef} className="absolute inset-0 w-full h-full" />
    </div>
  );
}
