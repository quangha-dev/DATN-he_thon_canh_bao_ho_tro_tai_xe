package com.safefleet.trip.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.trip.dto.request.AssignTripRequest;
import com.safefleet.trip.dto.request.CancelTripRequest;
import com.safefleet.trip.dto.request.CreateTripRequest;
import com.safefleet.trip.dto.request.TripActionRequest;
import com.safefleet.trip.dto.response.TripResponse;
import com.safefleet.trip.dto.response.TripTimelineResponse;
import com.safefleet.trip.enums.TripStatus;
import com.safefleet.trip.service.TripService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@Tag(name = "Trips", description = "Trip lifecycle and dispatch assignment APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trips")
public class TripController {

    private final TripService tripService;

    @Operation(summary = "Create trip")
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<TripResponse> create(@Valid @RequestBody CreateTripRequest request) {
        return ApiResponse.ok("Trip created", tripService.create(request));
    }

    @Operation(summary = "Search trips by status, vehicle, driver and date")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<PageResponse<TripResponse>> search(@RequestParam(required = false) TripStatus status,
                                                          @RequestParam(required = false) Long vehicleId,
                                                          @RequestParam(required = false) Long driverId,
                                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
                                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate,
                                                          Pageable pageable) {
        return ApiResponse.ok(tripService.search(status, vehicleId, driverId, fromDate, toDate, pageable));
    }

    @Operation(summary = "Get trip detail")
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<TripResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(tripService.get(id));
    }

    @Operation(summary = "Assign trip to vehicle and driver")
    @PostMapping("/{id}/assign")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<TripResponse> assign(@PathVariable Long id, @Valid @RequestBody AssignTripRequest request) {
        return ApiResponse.ok("Trip assigned", tripService.assign(id, request));
    }

    @Operation(summary = "Driver accepts assigned trip")
    @PostMapping("/{id}/accept")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<TripResponse> accept(@PathVariable Long id, @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Trip accepted", tripService.accept(id, request == null ? new TripActionRequest(null, null) : request));
    }

    @Operation(summary = "Start trip")
    @PostMapping("/{id}/start")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<TripResponse> start(@PathVariable Long id, @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Trip started", tripService.start(id, request == null ? new TripActionRequest(null, null) : request));
    }

    @Operation(summary = "Pause trip for rest")
    @PostMapping("/{id}/pause")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<TripResponse> pause(@PathVariable Long id, @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Trip paused", tripService.pause(id, request == null ? new TripActionRequest(null, null) : request));
    }

    @Operation(summary = "Resume trip")
    @PostMapping("/{id}/resume")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<TripResponse> resume(@PathVariable Long id, @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Trip resumed", tripService.resume(id, request == null ? new TripActionRequest(null, null) : request));
    }

    @Operation(summary = "Complete trip")
    @PostMapping("/{id}/complete")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<TripResponse> complete(@PathVariable Long id, @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Trip completed", tripService.complete(id, request == null ? new TripActionRequest(null, null) : request));
    }

    @Operation(summary = "Cancel trip")
    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<TripResponse> cancel(@PathVariable Long id, @Valid @RequestBody CancelTripRequest request) {
        return ApiResponse.ok("Trip cancelled", tripService.cancel(id, request));
    }

    @Operation(summary = "Get trip timeline")
    @GetMapping("/{id}/timeline")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<List<TripTimelineResponse>> timeline(@PathVariable Long id) {
        return ApiResponse.ok(tripService.timeline(id));
    }
}
