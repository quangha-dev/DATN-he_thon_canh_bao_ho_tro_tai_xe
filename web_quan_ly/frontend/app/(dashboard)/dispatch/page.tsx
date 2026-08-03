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
import { cn, formatDrivingTime } from "@/lib/utils";
import MapView from "@/components/map/MapView";
import {
  Route,
  Calendar,
  Sparkles,
  CheckCircle,
  MapPin,
  Compass,
  Clock,
  Loader2,
  PackagePlus,
  Plus,
  Trash2,
} from "lucide-react";
import { useToast } from "@/context/ToastContext";
import { useAuth } from "@/context/AuthContext";

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
      <label className="block text-xs font-semibold text-slate-500 uppercase mb-1.5">
        {label} *
      </label>
      <div className="relative">
        <MapPin className="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
        <input
          type="text"
          value={value}
          onChange={(event) => {
            onValueChange(event.target.value);
            setIsOpen(true);
          }}
          onFocus={() => setIsOpen(true)}
          placeholder={placeholder}
          className={cn(
            "w-full pl-9 pr-9 py-2 border rounded-lg text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2",
            error
              ? "border-red-400 focus:ring-red-500/20"
              : selected
                ? "border-emerald-300 dark:border-emerald-800 focus:ring-emerald-500/20"
                : "border-slate-200 dark:border-slate-800 focus:ring-blue-500/20"
          )}
          required
        />
        {isLoading && (
          <Loader2 className="absolute right-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-blue-500 animate-spin" />
        )}
        {!isLoading && selected && (
          <CheckCircle className="absolute right-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-emerald-500" />
        )}
      </div>

      {error && <p className="mt-1 text-[11px] font-medium text-red-500">{error}</p>}

      {isOpen && value.trim().length >= 2 && !selected && (
        <div className="absolute z-40 mt-1 w-full rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 shadow-xl overflow-hidden">
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
                className="w-full text-left px-3 py-2.5 hover:bg-blue-50 dark:hover:bg-slate-800 transition border-b last:border-b-0 border-slate-100 dark:border-slate-800"
              >
                <p className="text-xs font-semibold text-slate-900 dark:text-white truncate">
                  {suggestion.name}
                </p>
                <p className="text-[11px] text-slate-500 dark:text-slate-400 truncate mt-0.5">
                  {suggestion.address}
                </p>
              </button>
            ))
          ) : (
            <div className="px-3 py-3 text-[11px] text-slate-500 dark:text-slate-400">
              {isLoading ? "Đang tìm địa điểm..." : "Không tìm được địa điểm phù hợp"}
            </div>
          )}
        </div>
      )}
    </div>
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
    <div className="flex flex-col h-[calc(100vh-130px)] animate-fadeIn">
      <div className="flex-1 grid grid-cols-1 lg:grid-cols-2 gap-6 min-h-0 overflow-y-auto lg:overflow-hidden pb-4">
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm flex flex-col min-h-0 overflow-y-auto">
          <div className="flex items-center justify-between mb-5 flex-shrink-0">
            <h3 className="font-bold text-sm text-slate-900 dark:text-white flex items-center gap-2">
              <Route className="w-4.5 h-4.5 text-blue-500" />
              Thiết lập thông tin chuyến đi
            </h3>
            <button
              type="button"
              onClick={handleAiSuggest}
              disabled={isRecommending}
              className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-blue-50 dark:bg-blue-950/40 text-[11px] font-bold text-blue-600 dark:text-blue-400 border border-blue-200/50 dark:border-blue-800/50 hover:bg-blue-100 dark:hover:bg-blue-900/30 transition cursor-pointer disabled:opacity-60"
            >
              {isRecommending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Sparkles className="w-3.5 h-3.5" />}
              AI đề xuất xe & tài xế
            </button>
          </div>

          <form onSubmit={handleDispatch} className="space-y-4 flex-1">
            {recommendation && (
              <div className="p-4 rounded-xl bg-gradient-to-r from-blue-500/10 to-cyan-500/10 border border-blue-200/50 dark:border-blue-800/50 space-y-3 animate-fadeIn">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-blue-700 dark:text-blue-400 flex items-center gap-1.5">
                    <Sparkles className="w-3.5 h-3.5" /> Gợi ý tối ưu nhất từ AI
                  </span>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setRecommendation(null)}
                      className="text-[10px] text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 font-medium"
                    >
                      Bỏ qua
                    </button>
                    <button
                      type="button"
                      onClick={applyRecommendation}
                      className="text-[10px] text-blue-600 dark:text-blue-400 font-bold hover:underline"
                    >
                      Áp dụng
                    </button>
                  </div>
                </div>
                <div className="text-xs space-y-1 text-slate-700 dark:text-slate-300">
                  <p>
                    <span className="font-semibold">Xe:</span> {recommendation.vehicle.plate} ({recommendation.vehicle.brand})
                  </p>
                  <p>
                    <span className="font-semibold">Tài xế:</span> {recommendation.driver.fullName} (Safety Score: {recommendation.driver.safetyScore})
                  </p>
                  <div className="pt-2 pl-3 border-l border-blue-300 dark:border-blue-800 space-y-1">
                    {recommendation.reasons.map((reason) => (
                      <p key={reason} className="text-[11px] text-slate-500 dark:text-slate-400">
                        • {reason}
                      </p>
                    ))}
                  </div>
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-500 uppercase mb-1.5">Mã chuyến đi *</label>
                <input
                  type="text"
                  value={tripCode}
                  readOnly
                  className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400"
                />
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-500 uppercase mb-1.5">Loại chuyến đi *</label>
                <select
                  value={tripType}
                  onChange={(event) => setTripType(event.target.value)}
                  className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500/20"
                >
                  <option value="delivery">Vận chuyển hàng hóa</option>
                  <option value="passenger">Vận chuyển hành khách</option>
                  <option value="transfer">Trung chuyển nội bộ</option>
                </select>
              </div>
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
                <label className="block text-xs font-semibold text-slate-500 uppercase mb-1.5">Khởi hành dự kiến *</label>
                <div className="relative">
                  <Calendar className="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
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
                    className={cn(
                      "w-full pl-9 pr-3 py-2 border rounded-lg text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2",
                      fieldErrors.scheduledStart
                        ? "border-red-400 focus:ring-red-500/20"
                        : "border-slate-200 dark:border-slate-800 focus:ring-blue-500/20"
                    )}
                    required
                  />
                </div>
                {fieldErrors.scheduledStart && (
                  <p className="mt-1 text-[11px] font-medium text-red-500">{fieldErrors.scheduledStart}</p>
                )}
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-500 uppercase mb-1.5">Kết thúc dự kiến *</label>
                <div className="relative">
                  <Calendar className="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
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
                    className={cn(
                      "w-full pl-9 pr-3 py-2 border rounded-lg text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2",
                      fieldErrors.scheduledEnd
                        ? "border-red-400 focus:ring-red-500/20"
                        : "border-slate-200 dark:border-slate-800 focus:ring-blue-500/20"
                    )}
                    required
                  />
                </div>
                {fieldErrors.scheduledEnd && (
                  <p className="mt-1 text-[11px] font-medium text-red-500">{fieldErrors.scheduledEnd}</p>
                )}
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-500 uppercase mb-1.5">Tài xế + xe được phân công *</label>
              <select
                value={selectedFleetPair}
                onChange={(event) => {
                  const [driverId, vehicleId] = event.target.value.split(":");
                  setSelectedDriverId(driverId || "");
                  setSelectedVehicleId(vehicleId || "");
                }}
                className="w-full px-3 py-2.5 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500/20"
                required
              >
                <option value="">-- Chọn cặp tài xế + xe --</option>
                {isLoadingOptions && <option value="">Đang tải phân công...</option>}
                {fleetPairs.map(({ driver, vehicle }) => (
                  <option key={`${driver.id}:${vehicle.id}`} value={`${driver.id}:${vehicle.id}`}>
                    Tài xế {driver.code || driver.id} · {driver.fullName} — Xe {vehicle.code || vehicle.id} · {vehicle.plate}
                  </option>
                ))}
              </select>

              {!isLoadingOptions && fleetPairs.length === 0 && (
                <p className="mt-1.5 text-[11px] font-medium text-amber-600">
                  Chưa có tài xế và xe nào được liên kết cố định.
                </p>
              )}

              {selectedDriver && selectedVehicle && (
                <div className="mt-2.5 rounded-xl border border-slate-200 bg-slate-50 p-3.5 dark:border-slate-800 dark:bg-slate-800/50 animate-fadeIn">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-blue-600">Phân công cố định</p>
                      <p className="mt-1 text-sm font-bold text-slate-900 dark:text-white">
                        Tài xế {selectedDriver.code || selectedDriver.id} <span className="text-slate-400">×</span> Xe {selectedVehicle.code || selectedVehicle.id}
                      </p>
                      <p className="mt-0.5 text-[11px] text-slate-500">
                        {selectedDriver.fullName} · {selectedVehicle.plate} · {selectedVehicle.type} {selectedVehicle.brand}
                      </p>
                    </div>
                    <span className={cn(
                      "rounded-full px-2 py-1 text-[9px] font-bold uppercase",
                      selectedDriver.status === "available" && selectedVehicle.status === "idle"
                        ? "bg-emerald-100 text-emerald-700"
                        : "bg-amber-100 text-amber-700"
                    )}>
                      {selectedDriver.status === "available" && selectedVehicle.status === "idle" ? "Sẵn sàng" : "Cần kiểm tra"}
                    </span>
                  </div>
                  <div className="mt-3 grid grid-cols-2 gap-2 text-[10px] text-slate-500 dark:text-slate-400">
                    <p className="flex items-center gap-1"><CheckCircle className="h-3.5 w-3.5 text-emerald-500" /> GPS kết nối</p>
                    <p className="flex items-center gap-1"><CheckCircle className="h-3.5 w-3.5 text-emerald-500" /> Bằng {selectedDriver.licenseClass} hợp lệ</p>
                    <p className="col-span-2 flex items-center gap-1"><Clock className="h-3.5 w-3.5" /> Đã lái {formatDrivingTime(selectedDriver.drivingTimeToday)} hôm nay</p>
                  </div>
                </div>
              )}
            </div>

            <section className="rounded-2xl border border-blue-100 bg-blue-50/40 p-4 dark:border-blue-900/50 dark:bg-blue-950/20 space-y-4">
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <PackagePlus className="h-4.5 w-4.5 text-blue-600" />
                  <div>
                    <p className="text-xs font-bold text-slate-900 dark:text-white">Phiếu xuất kho điện tử</p>
                    <p className="text-[10px] text-slate-500">Thông tin bàn giao sẽ chuyển nguyên vẹn tới app tài xế</p>
                  </div>
                </div>
                <span className="rounded-full bg-white px-2 py-1 text-[9px] font-bold text-blue-700 shadow-sm dark:bg-slate-900 dark:text-blue-300">CHỜ XÁC NHẬN</span>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Đơn vị/doanh nghiệp</label>
                  <input value={companyName} onChange={(event) => setCompanyName(event.target.value)} placeholder="Tên đơn vị xuất kho" className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-white dark:bg-slate-900" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Địa chỉ đơn vị</label>
                  <input value={companyAddress} onChange={(event) => setCompanyAddress(event.target.value)} placeholder="Địa chỉ doanh nghiệp" className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-white dark:bg-slate-900" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Lý do/căn cứ xuất kho</label>
                  <input value={issueReason} onChange={(event) => setIssueReason(event.target.value)} placeholder="Xuất hàng cho công trình/đơn hàng..." className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-white dark:bg-slate-900" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Ngăn/lô/vị trí kho</label>
                  <input value={warehouseLocation} onChange={(event) => setWarehouseLocation(event.target.value)} placeholder="Ví dụ: Kho A · Lô 03" className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-white dark:bg-slate-900" />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Số phiếu xuất kho *</label>
                  <input value={warehouseIssueNumber} onChange={(event) => setWarehouseIssueNumber(event.target.value)} className={cn("w-full px-3 py-2 border rounded-lg text-xs bg-white dark:bg-slate-900", fieldErrors.warehouseIssueNumber ? "border-red-400" : "border-slate-200 dark:border-slate-800")} />
                  {fieldErrors.warehouseIssueNumber && <p className="mt-1 text-[10px] text-red-500">{fieldErrors.warehouseIssueNumber}</p>}
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Kho xuất hàng *</label>
                  <input value={warehouseName} onChange={(event) => setWarehouseName(event.target.value)} placeholder="Kho/ngăn/lô xuất hàng" className={cn("w-full px-3 py-2 border rounded-lg text-xs bg-white dark:bg-slate-900", fieldErrors.warehouseName ? "border-red-400" : "border-slate-200 dark:border-slate-800")} />
                  {fieldErrors.warehouseName && <p className="mt-1 text-[10px] text-red-500">{fieldErrors.warehouseName}</p>}
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Công trình/đơn vị nhận *</label>
                  <input value={projectName} onChange={(event) => setProjectName(event.target.value)} placeholder="Tên công trình hoặc đơn vị nhận" className={cn("w-full px-3 py-2 border rounded-lg text-xs bg-white dark:bg-slate-900", fieldErrors.projectName ? "border-red-400" : "border-slate-200 dark:border-slate-800")} />
                  {fieldErrors.projectName && <p className="mt-1 text-[10px] text-red-500">{fieldErrors.projectName}</p>}
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Hạng mục</label>
                  <input value={workItem} onChange={(event) => setWorkItem(event.target.value)} placeholder="Hạng mục thi công/sử dụng" className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-white dark:bg-slate-900" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Người nhận hàng *</label>
                  <input value={recipientName} onChange={(event) => setRecipientName(event.target.value)} placeholder="Họ tên người nhận" className={cn("w-full px-3 py-2 border rounded-lg text-xs bg-white dark:bg-slate-900", fieldErrors.recipientName ? "border-red-400" : "border-slate-200 dark:border-slate-800")} />
                  {fieldErrors.recipientName && <p className="mt-1 text-[10px] text-red-500">{fieldErrors.recipientName}</p>}
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Số điện thoại người nhận</label>
                  <input type="tel" value={recipientPhone} onChange={(event) => setRecipientPhone(event.target.value)} placeholder="Ví dụ: 0912 345 678" className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-white dark:bg-slate-900" />
                </div>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <p className="text-[10px] font-bold uppercase tracking-wide text-slate-500">Danh sách vật tư/hàng hóa *</p>
                  <button type="button" onClick={addCargoItem} className="inline-flex items-center gap-1 rounded-lg bg-blue-600 px-2.5 py-1.5 text-[10px] font-bold text-white hover:bg-blue-700"><Plus className="h-3 w-3" /> Thêm dòng</button>
                </div>
                {cargoItems.map((item, index) => (
                  <div key={item.id} className="rounded-xl border border-slate-200 bg-white p-3 dark:border-slate-800 dark:bg-slate-900">
                    <div className="mb-2 flex items-center justify-between">
                      <span className="text-[10px] font-bold text-blue-600">MẶT HÀNG {index + 1}</span>
                      <button type="button" disabled={cargoItems.length === 1} onClick={() => removeCargoItem(item.id)} className="text-slate-400 hover:text-red-500 disabled:opacity-30" aria-label={`Xóa mặt hàng ${index + 1}`}><Trash2 className="h-3.5 w-3.5" /></button>
                    </div>
                    <div className="grid grid-cols-2 md:grid-cols-6 gap-2">
                      <input value={item.itemCode} onChange={(event) => updateCargoItem(item.id, "itemCode", event.target.value)} placeholder="Mã số" className="px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                      <input value={item.description} onChange={(event) => updateCargoItem(item.id, "description", event.target.value)} placeholder="Tên, nhãn hiệu *" className="col-span-2 px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                      <input value={item.specification} onChange={(event) => updateCargoItem(item.id, "specification", event.target.value)} placeholder="Quy cách/phẩm chất" className="col-span-2 px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                      <input value={item.unit} onChange={(event) => updateCargoItem(item.id, "unit", event.target.value)} placeholder="Đơn vị *" className="px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                    </div>
                    <div className="mt-2 grid grid-cols-2 md:grid-cols-4 gap-2">
                      <input type="number" min="0" step="0.01" value={item.quantityRequested} onChange={(event) => updateCargoItem(item.id, "quantityRequested", event.target.value)} placeholder="SL theo chứng từ" className="px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                      <input type="number" min="0.01" step="0.01" value={item.quantityIssued} onChange={(event) => updateCargoItem(item.id, "quantityIssued", event.target.value)} placeholder="SL thực xuất *" className="px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                      <input type="number" min="0" step="0.01" value={item.quantityReturned} onChange={(event) => updateCargoItem(item.id, "quantityReturned", event.target.value)} placeholder="SL trả về" className="px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                      <input type="number" min="0" step="0.01" value={item.quantityDelivered} onChange={(event) => updateCargoItem(item.id, "quantityDelivered", event.target.value)} placeholder="SL thực giao" className="px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                    </div>
                    <div className="mt-2 grid grid-cols-1 md:grid-cols-2 gap-2">
                      <input value={item.conditionNote} onChange={(event) => updateCargoItem(item.id, "conditionNote", event.target.value)} placeholder="Tình trạng hàng khi xuất" className="w-full px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                      <input value={item.confirmation} onChange={(event) => updateCargoItem(item.id, "confirmation", event.target.value)} placeholder="Xác nhận/ghi chú" className="w-full px-2.5 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-[11px] bg-slate-50 dark:bg-slate-800" />
                    </div>
                  </div>
                ))}
                {fieldErrors.cargoItems && <p className="text-[10px] font-medium text-red-500">{fieldErrors.cargoItems}</p>}
              </div>

              <div>
                <label className="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1">Tổng số lượng bằng chữ</label>
                <input value={quantityInWords} onChange={(event) => setQuantityInWords(event.target.value)} placeholder="Ví dụ: Hai trăm tám mươi mét" className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-white dark:bg-slate-900" />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div><p className="text-[10px] uppercase text-slate-500">Người lập phiếu</p><p className="mt-1 text-xs font-bold text-slate-800 dark:text-slate-100">{user?.fullName || "Đang xác định..."}</p></div>
                <div><p className="text-[10px] uppercase text-slate-500">Người giao hàng</p><p className="mt-1 text-xs font-bold text-slate-800 dark:text-slate-100">{selectedDriver?.fullName || "Chọn tài xế"}</p></div>
              </div>
            </section>
            <div>
              <label className="block text-xs font-semibold text-slate-500 uppercase mb-1.5">Ghi chú điều phối</label>
              <input
                type="text"
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                placeholder="Lưu ý lộ trình, trạm dừng..."
                className="w-full px-3 py-2 border border-slate-200 dark:border-slate-800 rounded-lg text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none"
              />
            </div>
          </form>
        </div>

        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 overflow-hidden shadow-sm flex flex-col">
          <div className="px-5 py-3.5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between gap-2 flex-shrink-0">
            <div className="flex items-center gap-2">
              <Compass className="w-4.5 h-4.5 text-blue-500" />
              <h3 className="font-bold text-sm text-slate-900 dark:text-white">Xem trước tuyến lộ trình</h3>
            </div>
            {isRouting && (
              <span className="text-[11px] text-blue-500 font-semibold flex items-center gap-1">
                <Loader2 className="w-3.5 h-3.5 animate-spin" /> Đang tính tuyến
              </span>
            )}
          </div>
          <div className="flex-1 relative bg-slate-100 dark:bg-slate-950">
            <MapView
              interactive={false}
              routeCoordinates={routeCoordinates}
              routeStart={selectedOrigin ? { lat: selectedOrigin.lat, lng: selectedOrigin.lng, label: selectedOrigin.name } : null}
              routeEnd={selectedDestination ? { lat: selectedDestination.lat, lng: selectedDestination.lng, label: selectedDestination.name } : null}
            />
            <div className="absolute inset-0 bg-slate-900/10 pointer-events-none" />
            <div className="absolute bottom-4 left-4 right-4 sm:right-auto sm:max-w-md p-3 bg-white/95 dark:bg-slate-900/95 backdrop-blur-sm rounded-xl border border-slate-200/50 dark:border-slate-800/50 text-[10px] text-slate-500 dark:text-slate-400 space-y-1 shadow shadow-slate-950/10">
              <span className="font-semibold text-slate-700 dark:text-slate-300 block">
                {routeSummary ? `Tuyến ${routeSummary.provider}` : "Khu vực Hà Nội"}
              </span>
              {selectedOrigin && selectedDestination ? (
                <p className="line-clamp-2">
                  {selectedOrigin.name} → {selectedDestination.name}
                </p>
              ) : (
                <p>Nhập và chọn điểm đi/đến từ gợi ý để tính tuyến.</p>
              )}
              {routeError && <p className="text-amber-500 font-medium">{routeError}</p>}
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 p-4 shadow-sm flex items-center justify-between flex-shrink-0">
        <div className="flex items-center gap-6">
          <div>
            <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">Tổng quãng đường</span>
            <span className="text-base font-bold text-slate-900 dark:text-white">
              {routeSummary ? `${routeSummary.distanceKm.toFixed(1)} km` : "-- km"}
            </span>
          </div>
          <div className="w-px h-8 bg-slate-200 dark:bg-slate-800" />
          <div>
            <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">Thời gian dự kiến (ETA)</span>
            <span className="text-base font-bold text-slate-900 dark:text-white">
              {routeDuration}
            </span>
          </div>
          <div className="w-px h-8 bg-slate-200 dark:bg-slate-800" />
          <div>
            <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">Mức rủi ro tuyến đường</span>
            <span className="text-xs font-bold text-emerald-500 bg-emerald-50 dark:bg-emerald-950/30 px-2 py-0.5 rounded-full mt-0.5 inline-block">
              Thấp
            </span>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => submitDispatch(false)}
            disabled={isSubmitting}
            className="px-4 py-2 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg text-xs font-bold text-slate-700 dark:text-slate-300 transition cursor-pointer"
          >
            {isSubmitting ? "Đang lưu..." : "Lưu nháp"}
          </button>
          <button
            onClick={() => submitDispatch(true)}
            type="button"
            disabled={isSubmitting}
            className="px-5 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-lg shadow-md shadow-blue-500/10 transition cursor-pointer disabled:opacity-60"
          >
            {isSubmitting ? "Đang phát hành..." : "Phát hành & giao chuyến"}
          </button>
        </div>
      </div>
    </div>
  );
}
