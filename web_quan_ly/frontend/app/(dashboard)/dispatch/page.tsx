"use client";

import { useEffect, useMemo, useState } from "react";
import { Vehicle, Driver } from "@/types";
import {
  DispatchSuggestion,
  LocationSuggestion,
  RouteSummary,
  WarehouseIssueInput,
  safeFleetApi,
} from "@/lib/safeFleetApi";
import { formatDrivingTime } from "@/lib/utils";
import MapView from "@/components/map/MapView";
import {
  Route,
  Calendar,
  Sparkles,
  CheckCircle2,
  MapPin,
  Compass,
  Clock,
  Loader2,
  PackagePlus,
  Plus,
  Trash2,
  AlertTriangle,
} from "lucide-react";
import { useToast } from "@/context/ToastContext";
import { useAuth } from "@/context/AuthContext";
import {
  Badge,
  Button,
  Callout,
  Card,
  CardHeader,
  Field,
  TextInput,
} from "@/components/ui";

interface Recommendation {
  vehicle: Vehicle;
  driver: Driver;
  reasons: string[];
}

interface FleetPair {
  driver: Driver;
  vehicle: Vehicle;
}

interface CargoItem {
  id: string;
  itemCode: string;
  description: string;
  specification: string;
  unit: string;
  quantityRequested: string;
  quantityIssued: string;
  quantityReturned: string;
  quantityDelivered: string;
  conditionNote: string;
  confirmation: string;
}

type FieldErrors = {
  origin?: string;
  destination?: string;
  scheduledStart?: string;
  scheduledEnd?: string;
  warehouseIssueNumber?: string;
  recipientName?: string;
  projectName?: string;
  warehouseName?: string;
  cargoItems?: string;
};

interface LocationAutocompleteProps {
  label: string;
  value: string;
  selected: LocationSuggestion | null;
  placeholder: string;
  error?: string;
  onValueChange: (value: string) => void;
  onSelect: (suggestion: LocationSuggestion) => void;
}

function formatDuration(minutes: number) {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  if (hours <= 0) return `${mins} phút`;
  return `${hours} giờ ${mins.toString().padStart(2, "0")} phút`;
}

function toLocalDateTimeInput(date: Date) {
  const offsetMs = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offsetMs).toISOString().slice(0, 16);
}

function validateSchedule(start: string, end: string): FieldErrors {
  const errors: FieldErrors = {};
  if (!start) {
    errors.scheduledStart = "Vui lòng chọn thời gian đi";
  }
  if (!end) {
    errors.scheduledEnd = "Vui lòng chọn thời gian đến";
  }
  if (!start || !end) return errors;

  const startTime = new Date(start);
  const endTime = new Date(end);
  const now = new Date();
  now.setSeconds(0, 0);

  if (Number.isNaN(startTime.getTime())) {
    errors.scheduledStart = "Thời gian đi không hợp lệ";
  } else if (startTime < now) {
    errors.scheduledStart = "Thời gian đi không được ở quá khứ";
  }

  if (Number.isNaN(endTime.getTime())) {
    errors.scheduledEnd = "Thời gian đến không hợp lệ";
  } else if (!Number.isNaN(startTime.getTime()) && endTime <= startTime) {
    errors.scheduledEnd = "Thời gian đến phải sau thời gian đi";
  }

  return errors;
}

function LocationAutocomplete({
  label,
  value,
  selected,
  placeholder,
  error,
  onValueChange,
  onSelect,
}: LocationAutocompleteProps) {
  const [suggestions, setSuggestions] = useState<LocationSuggestion[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    const query = value.trim();
    if (query.length < 2 || selected?.address === value) {
      setSuggestions([]);
      setIsLoading(false);
      return;
    }

    let cancelled = false;
    setIsLoading(true);
    const timer = window.setTimeout(async () => {
      try {
        const data = await safeFleetApi.locationAutocomplete(query, 6);
        if (!cancelled) {
          setSuggestions(data);
          setIsOpen(true);
        }
      } catch {
        if (!cancelled) {
          setSuggestions([]);
          setIsOpen(true);
        }
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }, 450);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [value, selected]);

  return (
    <div className="relative">
      <span className="mb-1.5 block text-[12.5px] font-bold text-sf-text-secondary">
        {label} <Req />
      </span>
      <div className="relative">
        <MapPin className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-sf-text-muted" />
        <input
          type="text"
          value={value}
          onChange={(event) => {
            onValueChange(event.target.value);
            setIsOpen(true);
          }}
          onFocus={() => setIsOpen(true)}
          placeholder={placeholder}
          className="sf-input pl-9 pr-9"
          style={
            error
              ? { borderColor: "var(--sf-danger)" }
              : selected
                ? { borderColor: "var(--sf-success)" }
                : undefined
          }
          required
        />
        {isLoading && (
          <Loader2
            className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-sf-spin"
            style={{ color: "var(--sf-primary)" }}
          />
        )}
        {!isLoading && selected && (
          <CheckCircle2
            className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2"
            style={{ color: "var(--sf-success)" }}
          />
        )}
      </div>

      {error && <ErrorText>{error}</ErrorText>}

      {isOpen && value.trim().length >= 2 && !selected && (
        <div className="sf-glass-panel absolute z-40 mt-1.5 w-full animate-sf-drop overflow-hidden">
          {suggestions.length > 0 ? (
            suggestions.map((suggestion) => (
              <button
                type="button"
                key={`${suggestion.source}-${suggestion.id}`}
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => {
                  onSelect(suggestion);
                  setIsOpen(false);
                }}
                className="w-full border-b border-[var(--sf-border-light)] px-3.5 py-2.5 text-left transition-colors last:border-0 hover:bg-[var(--sf-primary-soft)] cursor-pointer"
              >
                <p className="truncate text-[12.5px] font-bold text-sf-text">{suggestion.name}</p>
                <p className="mt-0.5 truncate text-[12.5px] text-sf-text-muted">
                  {suggestion.address}
                </p>
              </button>
            ))
          ) : (
            <p className="px-3.5 py-3 text-[12.5px] text-sf-text-muted">
              {isLoading ? "Đang tìm địa điểm…" : "Không tìm được địa điểm phù hợp"}
            </p>
          )}
        </div>
      )}
    </div>
  );
}

function Req() {
  return <span style={{ color: "var(--sf-danger)" }}>*</span>;
}

function ErrorText({ children }: { children: React.ReactNode }) {
  return (
    <p className="mt-1 text-[12px] font-bold" style={{ color: "var(--sf-danger)" }}>
      {children}
    </p>
  );
}

function MiniField({
  label,
  required,
  error,
  children,
}: {
  label: string;
  required?: boolean;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-[12px] font-extrabold uppercase tracking-wide text-sf-text-muted">
        {label} {required && <Req />}
      </span>
      {children}
      {error && <ErrorText>{error}</ErrorText>}
    </label>
  );
}

export default function DispatchPage() {
  const { showToast } = useToast();
  const { user } = useAuth();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [isLoadingOptions, setIsLoadingOptions] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [tripCode, setTripCode] = useState("Sẽ cấp tự động khi lưu");
  const [draftTripId, setDraftTripId] = useState<string | null>(null);
  const [draftWarehouseIssueId, setDraftWarehouseIssueId] = useState<number | null>(null);
  const [tripType, setTripType] = useState("delivery");
  const [origin, setOrigin] = useState("");
  const [destination, setDestination] = useState("");
  const [selectedOrigin, setSelectedOrigin] = useState<LocationSuggestion | null>(null);
  const [selectedDestination, setSelectedDestination] = useState<LocationSuggestion | null>(null);
  const [scheduledStart, setScheduledStart] = useState("");
  const [scheduledEnd, setScheduledEnd] = useState("");
  const [selectedVehicleId, setSelectedVehicleId] = useState("");
  const [selectedDriverId, setSelectedDriverId] = useState("");
  const [warehouseIssueNumber, setWarehouseIssueNumber] = useState(
    () => `PXK-${new Date().toISOString().slice(0, 10).replaceAll("-", "")}-${Math.floor(100 + Math.random() * 900)}`
  );
  const [warehouseName, setWarehouseName] = useState("");
  const [warehouseLocation, setWarehouseLocation] = useState("");
  const [companyName, setCompanyName] = useState("");
  const [companyAddress, setCompanyAddress] = useState("");
  const [issueReason, setIssueReason] = useState("");
  const [projectName, setProjectName] = useState("");
  const [workItem, setWorkItem] = useState("");
  const [recipientName, setRecipientName] = useState("");
  const [recipientPhone, setRecipientPhone] = useState("");
  const [quantityInWords, setQuantityInWords] = useState("");
  const [cargoItems, setCargoItems] = useState<CargoItem[]>([
    { id: crypto.randomUUID(), itemCode: "", description: "", specification: "", unit: "", quantityRequested: "", quantityIssued: "", quantityReturned: "0", quantityDelivered: "", conditionNote: "", confirmation: "" },
  ]);
  const [notes, setNotes] = useState("");
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [routeSummary, setRouteSummary] = useState<RouteSummary | null>(null);
  const [isRouting, setIsRouting] = useState(false);
  const [routeError, setRouteError] = useState("");

  const [recommendation, setRecommendation] = useState<Recommendation | null>(null);
  const [isRecommending, setIsRecommending] = useState(false);

  const minDateTime = useMemo(() => toLocalDateTimeInput(new Date()), []);

  const updateCargoItem = (id: string, field: keyof Omit<CargoItem, "id">, value: string) => {
    setCargoItems((current) => current.map((item) => item.id === id ? { ...item, [field]: value } : item));
    setFieldErrors((current) => ({ ...current, cargoItems: undefined }));
  };

  const addCargoItem = () => setCargoItems((current) => [
    ...current,
    { id: crypto.randomUUID(), itemCode: "", description: "", specification: "", unit: "", quantityRequested: "", quantityIssued: "", quantityReturned: "0", quantityDelivered: "", conditionNote: "", confirmation: "" },
  ]);

  const removeCargoItem = (id: string) => {
    setCargoItems((current) => current.length === 1 ? current : current.filter((item) => item.id !== id));
  };

  useEffect(() => {
    let cancelled = false;

    const loadOptions = async () => {
      setIsLoadingOptions(true);
      try {
        const [vehicleData, driverData] = await Promise.all([
          safeFleetApi.vehicles(),
          safeFleetApi.drivers(),
        ]);
        if (!cancelled) {
          setVehicles(vehicleData);
          setDrivers(driverData);
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được dữ liệu điều phối.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoadingOptions(false);
      }
    };

    loadOptions();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  useEffect(() => {
    if (!selectedOrigin || !selectedDestination) {
      setRouteSummary(null);
      setRouteError("");
      return;
    }

    let cancelled = false;
    setIsRouting(true);
    setRouteError("");

    const loadRoute = async () => {
      try {
        const route = await safeFleetApi.routeSummary({
          startLat: selectedOrigin.lat,
          startLng: selectedOrigin.lng,
          endLat: selectedDestination.lat,
          endLng: selectedDestination.lng,
        });
        if (!cancelled) {
          setRouteSummary(route);
          if (route.fallback) {
            setRouteError("Đang dùng ETA ước tính vì dịch vụ tuyến đường chưa phản hồi.");
          }
        }
      } catch (error) {
        if (!cancelled) {
          setRouteSummary(null);
          setRouteError(error instanceof Error ? error.message : "Không tính được tuyến đường.");
        }
      } finally {
        if (!cancelled) setIsRouting(false);
      }
    };

    loadRoute();

    return () => {
      cancelled = true;
    };
  }, [selectedOrigin, selectedDestination]);

  const fleetPairs = useMemo<FleetPair[]>(() => drivers.flatMap((driver) => {
    const vehicle = vehicles.find((candidate) =>
      candidate.id === driver.currentVehicleId || candidate.currentDriverId === driver.id
    );
    return vehicle ? [{ driver, vehicle }] : [];
  }), [drivers, vehicles]);
  const selectedVehicle = vehicles.find((v) => v.id === selectedVehicleId);
  const selectedDriver = drivers.find((d) => d.id === selectedDriverId);
  const selectedFleetPair = selectedDriver && selectedVehicle
    ? `${selectedDriver.id}:${selectedVehicle.id}`
    : "";

  useEffect(() => {
    if (fleetPairs.length === 1 && !selectedDriverId && !selectedVehicleId) {
      setSelectedDriverId(fleetPairs[0].driver.id);
      setSelectedVehicleId(fleetPairs[0].vehicle.id);
    }
  }, [fleetPairs, selectedDriverId, selectedVehicleId]);

  const buildRecommendation = (suggestion?: DispatchSuggestion): Recommendation | null => {
    if (suggestion) {
      const vehicle = vehicles.find((v) => v.id === suggestion.vehicleId);
      const driver = drivers.find((d) => d.id === suggestion.driverId);
      if (vehicle && driver) {
        return {
          vehicle,
          driver,
          reasons: suggestion.reasons.length > 0 ? suggestion.reasons : ["Backend đánh giá phương án này phù hợp nhất."],
        };
      }
    }

    const bestVehicle = vehicles.find((v) => v.status === "idle" && v.gpsStatus === "online") || vehicles[0];
    const bestDriver = [...drivers]
      .filter((d) => d.status === "available")
      .sort((a, b) => b.safetyScore - a.safetyScore)[0] || drivers[0];

    if (!bestVehicle || !bestDriver) return null;

    return {
      vehicle: bestVehicle,
      driver: bestDriver,
      reasons: [
        `Tài xế có điểm an toàn ${bestDriver.safetyScore}.`,
        "Xe ở trạng thái phù hợp để điều phối.",
        `Thời gian lái hôm nay: ${formatDrivingTime(bestDriver.drivingTimeToday)}.`,
      ],
    };
  };

  const handleAiSuggest = async () => {
    setIsRecommending(true);
    try {
      const suggestions = await safeFleetApi.dispatchSuggestions();
      const nextRecommendation = buildRecommendation(suggestions[0]);
      if (!nextRecommendation) {
        showToast("Chưa có xe hoặc tài xế phù hợp.", "warning");
        return;
      }

      setRecommendation(nextRecommendation);
      showToast("Đã tìm thấy phương án điều phối phù hợp.", "success");
    } catch (error) {
      const fallback = buildRecommendation();
      if (fallback) {
        setRecommendation(fallback);
        showToast("Dùng gợi ý cục bộ vì backend chưa trả đề xuất.", "warning");
      } else {
        showToast(error instanceof Error ? error.message : "Không lấy được gợi ý điều phối.", "error");
      }
    } finally {
      setIsRecommending(false);
    }
  };

  const applyRecommendation = () => {
    if (recommendation) {
      setSelectedVehicleId(recommendation.vehicle.id);
      setSelectedDriverId(recommendation.driver.id);
      setRecommendation(null);
      showToast("Đã áp dụng đề xuất từ AI", "info");
    }
  };

  const validateForm = () => {
    const errors = validateSchedule(scheduledStart, scheduledEnd);
    if (!selectedOrigin) {
      errors.origin = "Chọn điểm xuất phát từ gợi ý";
    }
    if (!selectedDestination) {
      errors.destination = "Chọn điểm đến từ gợi ý";
    }
    if (!warehouseIssueNumber.trim()) errors.warehouseIssueNumber = "Vui lòng nhập số phiếu xuất kho";
    if (!recipientName.trim()) errors.recipientName = "Vui lòng nhập người nhận hàng";
    if (!projectName.trim()) errors.projectName = "Vui lòng nhập công trình/đơn vị nhận";
    if (!warehouseName.trim()) errors.warehouseName = "Vui lòng nhập kho xuất hàng";
    if (cargoItems.length === 0 || cargoItems.some((item) =>
      !item.description.trim() || !item.unit.trim() || Number(item.quantityIssued) <= 0
    )) {
      errors.cargoItems = "Mỗi dòng hàng cần có tên/quy cách, đơn vị và số lượng xuất lớn hơn 0";
    }
    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const submitDispatch = async (issueDocument = true) => {
    if (!selectedVehicleId || !selectedDriverId) {
      showToast("Vui lòng chọn cặp tài xế và xe", "warning");
      return;
    }
    if (!validateForm()) {
      showToast("Vui lòng kiểm tra lại thông tin chuyến đi", "warning");
      return;
    }

    setIsSubmitting(true);
    try {
      const tripInput = {
        startLocation: selectedOrigin!.address,
        startLat: selectedOrigin!.lat,
        startLng: selectedOrigin!.lng,
        endLocation: selectedDestination!.address,
        endLat: selectedDestination!.lat,
        endLng: selectedDestination!.lng,
        plannedStartTime: scheduledStart,
        estimatedEndTime: scheduledEnd,
        riskLevel: routeSummary?.fallback ? ("medium" as const) : ("low" as const),
        plannedRoute: JSON.stringify({
          tripType,
          notes,
          dispatchedBy: user ? { id: user.id, fullName: user.fullName } : null,
          route: routeSummary,
        }),
      };
      let trip;
      if (draftTripId) {
        trip = await safeFleetApi.updateTripDraft(draftTripId, tripInput);
        if (issueDocument) {
          trip = await safeFleetApi.assignTrip(draftTripId, selectedDriverId, selectedVehicleId);
        }
      } else {
        trip = await safeFleetApi.createTrip({
          ...tripInput,
          vehicleId: issueDocument ? selectedVehicleId : undefined,
          driverId: issueDocument ? selectedDriverId : undefined,
        });
      }

      const warehouseInput: WarehouseIssueInput = {
        tripId: Number(trip.id),
        issueNumber: warehouseIssueNumber.trim(),
        issueDate: scheduledStart.slice(0, 10),
        companyName: companyName.trim() || undefined,
        companyAddress: companyAddress.trim() || undefined,
        issueReason: issueReason.trim() || undefined,
        warehouseName: warehouseName.trim(),
        warehouseLocation: warehouseLocation.trim() || undefined,
        projectName: projectName.trim(),
        workItem: workItem.trim() || undefined,
        recipientName: recipientName.trim(),
        recipientPhone: recipientPhone.trim() || undefined,
        deliveryAddress: selectedDestination!.address,
        deliveryPersonName: selectedDriver?.fullName,
        quantityInWords: quantityInWords.trim() || undefined,
        notes: notes.trim() || undefined,
        items: cargoItems.map((item) => ({
          itemCode: item.itemCode.trim() || undefined,
          description: item.description.trim(),
          specification: item.specification.trim() || undefined,
          unit: item.unit.trim(),
          requestedQuantity: item.quantityRequested ? Number(item.quantityRequested) : undefined,
          issuedQuantity: Number(item.quantityIssued),
          returnedQuantity: Number(item.quantityReturned || 0),
          deliveredQuantity: item.quantityDelivered ? Number(item.quantityDelivered) : undefined,
          conditionNote: item.conditionNote.trim() || undefined,
          confirmationNote: item.confirmation.trim() || undefined,
        })),
      };
      const warehouseIssue = draftWarehouseIssueId
        ? await safeFleetApi.updateWarehouseIssue(draftWarehouseIssueId, warehouseInput)
        : await safeFleetApi.createWarehouseIssue(warehouseInput);
      if (issueDocument) {
        await safeFleetApi.issueWarehouseIssue(warehouseIssue.id);
        setDraftTripId(null);
        setDraftWarehouseIssueId(null);
      } else {
        setDraftTripId(trip.id);
        setDraftWarehouseIssueId(warehouseIssue.id);
      }
      setTripCode(trip.code);
      showToast(
        issueDocument
          ? `Đã phát hành ${warehouseIssue.issueNumber} và giao chuyến ${trip.code}.`
          : `Đã lưu nháp ${warehouseIssue.issueNumber} cho chuyến ${trip.code}.`,
        "success"
      );
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể giao chuyến.", "error");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDispatch = async (event: React.FormEvent) => {
    event.preventDefault();
    await submitDispatch(true);
  };

  const routeCoordinates = routeSummary?.coordinates ?? [];
  const routeDuration = routeSummary ? formatDuration(routeSummary.durationMinutes) : "-- giờ -- phút";

  return (
    <div className="flex h-[calc(100vh-116px)] flex-col gap-4">
      <div className="grid min-h-0 flex-1 grid-cols-1 gap-5 overflow-y-auto pb-1 lg:grid-cols-2 lg:overflow-hidden">
        {/* ===== Cột trái: biểu mẫu ===== */}
        <Card padding="none" className="flex min-h-0 flex-col">
          <div className="flex flex-shrink-0 items-center justify-between gap-3 border-b border-[var(--sf-border)] px-5 py-3.5">
            <CardHeader
              title="Thiết lập chuyến đi"
              subtitle="Thông tin lộ trình và phiếu xuất kho"
              icon={Route}
            />
            <Button
              type="button"
              size="xs"
              variant="accent"
              icon={Sparkles}
              loading={isRecommending}
              onClick={handleAiSuggest}
            >
              AI đề xuất
            </Button>
          </div>

          <form
            onSubmit={handleDispatch}
            className="min-h-0 flex-1 space-y-4 overflow-y-auto p-5"
          >
            {recommendation && (
              <div
                className="animate-sf-scale space-y-3 rounded-[var(--sf-r-md)] border-l-[3px] p-4"
                style={{
                  background: "var(--sf-accent-soft)",
                  borderLeftColor: "var(--sf-accent)",
                }}
              >
                <div className="flex items-center justify-between gap-2">
                  <span
                    className="flex items-center gap-1.5 text-[12px] font-extrabold"
                    style={{ color: "var(--sf-accent-hover)" }}
                  >
                    <Sparkles className="h-3.5 w-3.5" /> Gợi ý tối ưu từ AI
                  </span>
                  <div className="flex gap-1.5">
                    <Button
                      type="button"
                      size="xs"
                      variant="ghost"
                      onClick={() => setRecommendation(null)}
                    >
                      Bỏ qua
                    </Button>
                    <Button type="button" size="xs" onClick={applyRecommendation}>
                      Áp dụng
                    </Button>
                  </div>
                </div>
                <div className="space-y-1 text-[12px] text-sf-text-secondary">
                  <p>
                    <span className="font-bold text-sf-text">Xe:</span>{" "}
                    {recommendation.vehicle.plate} ({recommendation.vehicle.brand})
                  </p>
                  <p>
                    <span className="font-bold text-sf-text">Tài xế:</span>{" "}
                    {recommendation.driver.fullName} · điểm an toàn{" "}
                    {recommendation.driver.safetyScore}
                  </p>
                  <ul className="mt-2 space-y-1 border-l border-[var(--sf-border-strong)] pl-3">
                    {recommendation.reasons.map((reason) => (
                      <li key={reason} className="text-[12.5px] text-sf-text-muted">
                        {reason}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 gap-4">
              <Field label="Mã chuyến đi">
                <TextInput value={tripCode} readOnly mono className="opacity-70" />
              </Field>
              <Field label="Loại chuyến đi">
                <select
                  value={tripType}
                  onChange={(event) => setTripType(event.target.value)}
                  className="sf-input sf-select cursor-pointer font-semibold"
                >
                  <option value="delivery">Vận chuyển hàng hóa</option>
                  <option value="passenger">Vận chuyển hành khách</option>
                  <option value="transfer">Trung chuyển nội bộ</option>
                </select>
              </Field>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <LocationAutocomplete
                label="Điểm xuất phát"
                value={origin}
                selected={selectedOrigin}
                placeholder="Nhập địa điểm đi..."
                error={fieldErrors.origin}
                onValueChange={(value) => {
                  setOrigin(value);
                  setSelectedOrigin(null);
                  setRouteSummary(null);
                  setFieldErrors((current) => ({ ...current, origin: undefined }));
                }}
                onSelect={(suggestion) => {
                  setSelectedOrigin(suggestion);
                  setOrigin(suggestion.address);
                  setFieldErrors((current) => ({ ...current, origin: undefined }));
                }}
              />
              <LocationAutocomplete
                label="Điểm đến"
                value={destination}
                selected={selectedDestination}
                placeholder="Nhập địa điểm đến..."
                error={fieldErrors.destination}
                onValueChange={(value) => {
                  setDestination(value);
                  setSelectedDestination(null);
                  setRouteSummary(null);
                  setFieldErrors((current) => ({ ...current, destination: undefined }));
                }}
                onSelect={(suggestion) => {
                  setSelectedDestination(suggestion);
                  setDestination(suggestion.address);
                  setFieldErrors((current) => ({ ...current, destination: undefined }));
                }}
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <span className="mb-1.5 block text-[12.5px] font-bold text-sf-text-secondary">
                  Khởi hành dự kiến <Req />
                </span>
                <div className="relative">
                  <Calendar className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-sf-text-muted" />
                  <input
                    type="datetime-local"
                    value={scheduledStart}
                    min={minDateTime}
                    onChange={(event) => {
                      setScheduledStart(event.target.value);
                      const scheduleErrors = validateSchedule(event.target.value, scheduledEnd);
                      setFieldErrors((current) => ({
                        ...current,
                        scheduledStart: scheduleErrors.scheduledStart,
                        scheduledEnd: scheduleErrors.scheduledEnd,
                      }));
                    }}
                    className="sf-input pl-9"
                    style={
                      fieldErrors.scheduledStart
                        ? { borderColor: "var(--sf-danger)" }
                        : undefined
                    }
                    required
                  />
                </div>
                {fieldErrors.scheduledStart && (
                  <ErrorText>{fieldErrors.scheduledStart}</ErrorText>
                )}
              </div>
              <div>
                <span className="mb-1.5 block text-[12.5px] font-bold text-sf-text-secondary">
                  Kết thúc dự kiến <Req />
                </span>
                <div className="relative">
                  <Calendar className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-sf-text-muted" />
                  <input
                    type="datetime-local"
                    value={scheduledEnd}
                    min={scheduledStart || minDateTime}
                    onChange={(event) => {
                      setScheduledEnd(event.target.value);
                      const scheduleErrors = validateSchedule(scheduledStart, event.target.value);
                      setFieldErrors((current) => ({
                        ...current,
                        scheduledStart: scheduleErrors.scheduledStart,
                        scheduledEnd: scheduleErrors.scheduledEnd,
                      }));
                    }}
                    className="sf-input pl-9"
                    style={
                      fieldErrors.scheduledEnd ? { borderColor: "var(--sf-danger)" } : undefined
                    }
                    required
                  />
                </div>
                {fieldErrors.scheduledEnd && <ErrorText>{fieldErrors.scheduledEnd}</ErrorText>}
              </div>
            </div>

            <div>
              <span className="mb-1.5 block text-[12.5px] font-bold text-sf-text-secondary">
                Tài xế + xe được phân công <Req />
              </span>
              <select
                value={selectedFleetPair}
                onChange={(event) => {
                  const [driverId, vehicleId] = event.target.value.split(":");
                  setSelectedDriverId(driverId || "");
                  setSelectedVehicleId(vehicleId || "");
                }}
                className="sf-input sf-select cursor-pointer font-semibold"
                required
              >
                <option value="">— Chọn cặp tài xế + xe —</option>
                {isLoadingOptions && <option value="">Đang tải phân công…</option>}
                {fleetPairs.map(({ driver, vehicle }) => (
                  <option key={`${driver.id}:${vehicle.id}`} value={`${driver.id}:${vehicle.id}`}>
                    Tài xế {driver.code || driver.id} · {driver.fullName} — Xe{" "}
                    {vehicle.code || vehicle.id} · {vehicle.plate}
                  </option>
                ))}
              </select>

              {!isLoadingOptions && fleetPairs.length === 0 && (
                <Callout tone="warning" icon={AlertTriangle} className="mt-2">
                  Chưa có tài xế và xe nào được liên kết cố định.
                </Callout>
              )}

              {selectedDriver && selectedVehicle && (
                <div className="sf-inset mt-2.5 animate-sf-scale p-3.5">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="sf-eyebrow" style={{ color: "var(--sf-primary)" }}>
                        Phân công cố định
                      </p>
                      <p className="mt-1 text-[13.5px] font-extrabold text-sf-text">
                        Tài xế {selectedDriver.code || selectedDriver.id}{" "}
                        <span className="text-sf-text-muted">×</span> Xe{" "}
                        {selectedVehicle.code || selectedVehicle.id}
                      </p>
                      <p className="mt-0.5 truncate text-[12.5px] text-sf-text-muted">
                        {selectedDriver.fullName} · {selectedVehicle.plate} ·{" "}
                        {selectedVehicle.type} {selectedVehicle.brand}
                      </p>
                    </div>
                    <Badge
                      tone={
                        selectedDriver.status === "available" && selectedVehicle.status === "idle"
                          ? "success"
                          : "warning"
                      }
                      size="sm"
                    >
                      {selectedDriver.status === "available" && selectedVehicle.status === "idle"
                        ? "Sẵn sàng"
                        : "Cần kiểm tra"}
                    </Badge>
                  </div>
                  <div className="mt-3 grid grid-cols-2 gap-2 text-[12px] text-sf-text-muted">
                    <p className="flex items-center gap-1.5">
                      <CheckCircle2 className="h-3.5 w-3.5" style={{ color: "var(--sf-success)" }} />
                      GPS kết nối
                    </p>
                    <p className="flex items-center gap-1.5">
                      <CheckCircle2 className="h-3.5 w-3.5" style={{ color: "var(--sf-success)" }} />
                      Bằng {selectedDriver.licenseClass} hợp lệ
                    </p>
                    <p className="col-span-2 flex items-center gap-1.5">
                      <Clock className="h-3.5 w-3.5" />
                      Đã lái {formatDrivingTime(selectedDriver.drivingTimeToday)} hôm nay
                    </p>
                  </div>
                </div>
              )}
            </div>

            {/* ===== Phiếu xuất kho ===== */}
            <section
              className="space-y-4 rounded-[var(--sf-r-lg)] border p-4"
              style={{
                background: "var(--sf-primary-soft)",
                borderColor: "color-mix(in srgb, var(--sf-primary) 22%, transparent)",
              }}
            >
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2.5">
                  <span
                    className="grid h-8 w-8 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)]"
                    style={{ background: "var(--sf-primary)", color: "var(--sf-primary-contrast)" }}
                  >
                    <PackagePlus className="h-4 w-4" />
                  </span>
                  <div className="min-w-0">
                    <p className="text-[12.5px] font-extrabold text-sf-text">
                      Phiếu xuất kho điện tử
                    </p>
                    <p className="text-[12px] text-sf-text-muted">
                      Chuyển nguyên vẹn tới app tài xế
                    </p>
                  </div>
                </div>
                <Badge tone="accent" size="sm">
                  Chờ xác nhận
                </Badge>
              </div>

              <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                <MiniField label="Đơn vị / doanh nghiệp">
                  <TextInput
                    value={companyName}
                    onChange={(e) => setCompanyName(e.target.value)}
                    placeholder="Tên đơn vị xuất kho"
                  />
                </MiniField>
                <MiniField label="Địa chỉ đơn vị">
                  <TextInput
                    value={companyAddress}
                    onChange={(e) => setCompanyAddress(e.target.value)}
                    placeholder="Địa chỉ doanh nghiệp"
                  />
                </MiniField>
                <MiniField label="Lý do / căn cứ xuất kho">
                  <TextInput
                    value={issueReason}
                    onChange={(e) => setIssueReason(e.target.value)}
                    placeholder="Xuất hàng cho công trình/đơn hàng…"
                  />
                </MiniField>
                <MiniField label="Ngăn / lô / vị trí kho">
                  <TextInput
                    value={warehouseLocation}
                    onChange={(e) => setWarehouseLocation(e.target.value)}
                    placeholder="Ví dụ: Kho A · Lô 03"
                  />
                </MiniField>
                <MiniField
                  label="Số phiếu xuất kho"
                  required
                  error={fieldErrors.warehouseIssueNumber}
                >
                  <TextInput
                    mono
                    value={warehouseIssueNumber}
                    onChange={(e) => setWarehouseIssueNumber(e.target.value)}
                    style={
                      fieldErrors.warehouseIssueNumber
                        ? { borderColor: "var(--sf-danger)" }
                        : undefined
                    }
                  />
                </MiniField>
                <MiniField label="Kho xuất hàng" required error={fieldErrors.warehouseName}>
                  <TextInput
                    value={warehouseName}
                    onChange={(e) => setWarehouseName(e.target.value)}
                    placeholder="Kho/ngăn/lô xuất hàng"
                    style={
                      fieldErrors.warehouseName ? { borderColor: "var(--sf-danger)" } : undefined
                    }
                  />
                </MiniField>
                <MiniField label="Công trình / đơn vị nhận" required error={fieldErrors.projectName}>
                  <TextInput
                    value={projectName}
                    onChange={(e) => setProjectName(e.target.value)}
                    placeholder="Tên công trình hoặc đơn vị nhận"
                    style={
                      fieldErrors.projectName ? { borderColor: "var(--sf-danger)" } : undefined
                    }
                  />
                </MiniField>
                <MiniField label="Hạng mục">
                  <TextInput
                    value={workItem}
                    onChange={(e) => setWorkItem(e.target.value)}
                    placeholder="Hạng mục thi công/sử dụng"
                  />
                </MiniField>
                <MiniField label="Người nhận hàng" required error={fieldErrors.recipientName}>
                  <TextInput
                    value={recipientName}
                    onChange={(e) => setRecipientName(e.target.value)}
                    placeholder="Họ tên người nhận"
                    style={
                      fieldErrors.recipientName ? { borderColor: "var(--sf-danger)" } : undefined
                    }
                  />
                </MiniField>
                <MiniField label="SĐT người nhận">
                  <TextInput
                    type="tel"
                    value={recipientPhone}
                    onChange={(e) => setRecipientPhone(e.target.value)}
                    placeholder="Ví dụ: 0912 345 678"
                  />
                </MiniField>
              </div>

              {/* Danh sách hàng hóa */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <p className="sf-eyebrow">
                    Danh sách vật tư / hàng hóa <Req />
                  </p>
                  <Button type="button" size="xs" icon={Plus} onClick={addCargoItem}>
                    Thêm dòng
                  </Button>
                </div>

                {cargoItems.map((item, index) => (
                  <div
                    key={item.id}
                    className="rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] p-3"
                  >
                    <div className="mb-2 flex items-center justify-between">
                      <span
                        className="text-[12px] font-extrabold uppercase tracking-wide"
                        style={{ color: "var(--sf-primary)" }}
                      >
                        Mặt hàng {index + 1}
                      </span>
                      <button
                        type="button"
                        disabled={cargoItems.length === 1}
                        onClick={() => removeCargoItem(item.id)}
                        aria-label={`Xóa mặt hàng ${index + 1}`}
                        className="grid h-6 w-6 place-items-center rounded-[var(--sf-r-xs)] text-sf-text-muted transition-colors hover:bg-[var(--sf-danger-soft)] disabled:opacity-30 cursor-pointer"
                        style={{ color: cargoItems.length === 1 ? undefined : "var(--sf-danger)" }}
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>

                    <div className="grid grid-cols-2 gap-2 md:grid-cols-6">
                      <TextInput
                        value={item.itemCode}
                        onChange={(e) => updateCargoItem(item.id, "itemCode", e.target.value)}
                        placeholder="Mã số"
                      />
                      <TextInput
                        className="col-span-2"
                        value={item.description}
                        onChange={(e) => updateCargoItem(item.id, "description", e.target.value)}
                        placeholder="Tên, nhãn hiệu *"
                      />
                      <TextInput
                        className="col-span-2"
                        value={item.specification}
                        onChange={(e) => updateCargoItem(item.id, "specification", e.target.value)}
                        placeholder="Quy cách/phẩm chất"
                      />
                      <TextInput
                        value={item.unit}
                        onChange={(e) => updateCargoItem(item.id, "unit", e.target.value)}
                        placeholder="Đơn vị *"
                      />
                    </div>

                    <div className="mt-2 grid grid-cols-2 gap-2 md:grid-cols-4">
                      <TextInput
                        type="number"
                        min="0"
                        step="0.01"
                        value={item.quantityRequested}
                        onChange={(e) =>
                          updateCargoItem(item.id, "quantityRequested", e.target.value)
                        }
                        placeholder="SL chứng từ"
                      />
                      <TextInput
                        type="number"
                        min="0.01"
                        step="0.01"
                        value={item.quantityIssued}
                        onChange={(e) => updateCargoItem(item.id, "quantityIssued", e.target.value)}
                        placeholder="SL thực xuất *"
                      />
                      <TextInput
                        type="number"
                        min="0"
                        step="0.01"
                        value={item.quantityReturned}
                        onChange={(e) =>
                          updateCargoItem(item.id, "quantityReturned", e.target.value)
                        }
                        placeholder="SL trả về"
                      />
                      <TextInput
                        type="number"
                        min="0"
                        step="0.01"
                        value={item.quantityDelivered}
                        onChange={(e) =>
                          updateCargoItem(item.id, "quantityDelivered", e.target.value)
                        }
                        placeholder="SL thực giao"
                      />
                    </div>

                    <div className="mt-2 grid grid-cols-1 gap-2 md:grid-cols-2">
                      <TextInput
                        value={item.conditionNote}
                        onChange={(e) => updateCargoItem(item.id, "conditionNote", e.target.value)}
                        placeholder="Tình trạng hàng khi xuất"
                      />
                      <TextInput
                        value={item.confirmation}
                        onChange={(e) => updateCargoItem(item.id, "confirmation", e.target.value)}
                        placeholder="Xác nhận / ghi chú"
                      />
                    </div>
                  </div>
                ))}

                {fieldErrors.cargoItems && <ErrorText>{fieldErrors.cargoItems}</ErrorText>}
              </div>

              <MiniField label="Tổng số lượng bằng chữ">
                <TextInput
                  value={quantityInWords}
                  onChange={(e) => setQuantityInWords(e.target.value)}
                  placeholder="Ví dụ: Hai trăm tám mươi mét"
                />
              </MiniField>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <p className="sf-eyebrow">Người lập phiếu</p>
                  <p className="mt-1 text-[12.5px] font-bold text-sf-text">
                    {user?.fullName || "Đang xác định…"}
                  </p>
                </div>
                <div>
                  <p className="sf-eyebrow">Người giao hàng</p>
                  <p className="mt-1 text-[12.5px] font-bold text-sf-text">
                    {selectedDriver?.fullName || "Chọn tài xế"}
                  </p>
                </div>
              </div>
            </section>

            <Field label="Ghi chú điều phối">
              <TextInput
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Lưu ý lộ trình, trạm dừng…"
              />
            </Field>
          </form>
        </Card>

        {/* ===== Cột phải: xem trước tuyến ===== */}
        <Card padding="none" className="flex flex-col">
          <div className="flex flex-shrink-0 items-center justify-between gap-2 border-b border-[var(--sf-border)] px-5 py-3.5">
            <CardHeader
              title="Xem trước tuyến lộ trình"
              subtitle={routeSummary ? `Nguồn: ${routeSummary.provider}` : "Khu vực Hà Nội"}
              icon={Compass}
            />
            {isRouting && (
              <span className="flex flex-shrink-0 items-center gap-1.5 text-[12.5px] font-bold text-sf-text-muted">
                <Loader2 className="h-3.5 w-3.5 animate-sf-spin" /> Đang tính tuyến
              </span>
            )}
          </div>

          <div className="sf-map-dark relative min-h-[18rem] flex-1">
            <MapView
              interactive={false}
              routeCoordinates={routeCoordinates}
              routeStart={
                selectedOrigin
                  ? { lat: selectedOrigin.lat, lng: selectedOrigin.lng, label: selectedOrigin.name }
                  : null
              }
              routeEnd={
                selectedDestination
                  ? {
                      lat: selectedDestination.lat,
                      lng: selectedDestination.lng,
                      label: selectedDestination.name,
                    }
                  : null
              }
            />
            <div className="sf-glass-panel absolute bottom-4 left-4 right-4 space-y-1 p-3 text-[12.5px] sm:right-auto sm:max-w-md">
              {selectedOrigin && selectedDestination ? (
                <p className="line-clamp-2 font-bold text-sf-text">
                  {selectedOrigin.name} → {selectedDestination.name}
                </p>
              ) : (
                <p className="text-sf-text-muted">
                  Nhập và chọn điểm đi/đến từ gợi ý để tính tuyến.
                </p>
              )}
              {routeError && (
                <p className="font-bold" style={{ color: "var(--sf-accent-hover)" }}>
                  {routeError}
                </p>
              )}
            </div>
          </div>
        </Card>
      </div>

      {/* ===== Thanh tổng kết ===== */}
      <Card padding="sm" className="flex-shrink-0">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex flex-wrap items-center gap-5">
            <div>
              <p className="sf-eyebrow">Tổng quãng đường</p>
              <p className="sf-metric mt-1 text-[19px]">
                {routeSummary ? `${routeSummary.distanceKm.toFixed(1)} km` : "— km"}
              </p>
            </div>
            <span className="h-9 w-px bg-[var(--sf-border)]" />
            <div>
              <p className="sf-eyebrow">Thời gian dự kiến</p>
              <p className="sf-metric mt-1 text-[19px]">{routeDuration}</p>
            </div>
            <span className="h-9 w-px bg-[var(--sf-border)]" />
            <div>
              <p className="sf-eyebrow">Mức rủi ro tuyến</p>
              <Badge tone={routeSummary?.fallback ? "warning" : "success"} className="mt-1.5">
                {routeSummary?.fallback ? "Trung bình" : "Thấp"}
              </Badge>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              loading={isSubmitting}
              onClick={() => submitDispatch(false)}
            >
              Lưu nháp
            </Button>
            <Button
              type="button"
              size="sm"
              icon={CheckCircle2}
              loading={isSubmitting}
              onClick={() => submitDispatch(true)}
            >
              Phát hành &amp; giao chuyến
            </Button>
          </div>
        </div>
      </Card>
    </div>
  );
}
