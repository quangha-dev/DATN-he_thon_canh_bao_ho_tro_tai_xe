package com.safefleet.dispatch.service;

import com.safefleet.common.exception.NotFoundException;
import com.safefleet.common.util.GeoUtils;
import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.dispatch.dto.response.AvailabilityResponse;
import com.safefleet.dispatch.dto.response.DispatchSuggestionResponse;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DispatchService {

    private final VehicleRepository vehicleRepository;
    private final DriverRepository driverRepository;

    @Transactional(readOnly = true)
    public List<DispatchSuggestionResponse> suggestions(Double startLat, Double startLng, int limit) {
        List<Vehicle> vehicles = vehicleRepository.findByDeletedFalseAndStatus(VehicleStatus.AVAILABLE).stream()
                .filter(this::isVehicleEligible)
                .toList();
        List<Driver> drivers = driverRepository.findByDeletedFalseAndStatus(DriverStatus.AVAILABLE).stream()
                .filter(this::isDriverEligible)
                .toList();

        List<DispatchSuggestionResponse> suggestions = new ArrayList<>();
        for (Vehicle vehicle : vehicles) {
            for (Driver driver : drivers) {
                Double distance = (startLat == null || startLng == null)
                        ? null
                        : GeoUtils.distanceKm(startLat, startLng, vehicle.getLastLat(), vehicle.getLastLng());
                double score = score(vehicle, driver, distance);
                suggestions.add(new DispatchSuggestionResponse(
                        vehicle.getId(),
                        vehicle.getPlateNumber(),
                        driver.getId(),
                        driver.getFullName(),
                        score,
                        distance == null || distance == Double.MAX_VALUE ? null : distance,
                        reasons(vehicle, driver, distance)
                ));
            }
        }

        return suggestions.stream()
                .sorted(Comparator.comparingDouble(DispatchSuggestionResponse::score).reversed())
                .limit(Math.max(1, limit))
                .toList();
    }

    @Transactional(readOnly = true)
    public AvailabilityResponse availability(Long vehicleId, Long driverId) {
        Vehicle vehicle = vehicleRepository.findById(vehicleId)
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", vehicleId));
        Driver driver = driverRepository.findById(driverId)
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Driver", driverId));
        List<String> reasons = new ArrayList<>();
        boolean vehicleAvailable = isVehicleEligible(vehicle);
        boolean driverAvailable = isDriverEligible(driver);
        if (!vehicleAvailable) {
            reasons.add("Vehicle is not dispatch eligible");
        }
        if (!driverAvailable) {
            reasons.add("Driver is not dispatch eligible");
        }
        return new AvailabilityResponse(vehicleId, vehicleAvailable, driverId, driverAvailable,
                vehicleAvailable && driverAvailable, reasons);
    }

    private boolean isVehicleEligible(Vehicle vehicle) {
        return vehicle.getStatus() == VehicleStatus.AVAILABLE
                && vehicle.getGpsDevice() != null
                && vehicle.getGpsDevice().getStatus() == DeviceStatus.ONLINE
                && (vehicle.getInspectionExpiredAt() == null || !vehicle.getInspectionExpiredAt().isBefore(LocalDate.now()));
    }

    private boolean isDriverEligible(Driver driver) {
        return driver.getStatus() == DriverStatus.AVAILABLE
                && driver.getContinuousDrivingMinutes() < 210
                && driver.getSafetyScore() >= 60;
    }

    private double score(Vehicle vehicle, Driver driver, Double distance) {
        double score = driver.getSafetyScore();
        score += vehicle.getLastUpdatedAt() == null ? 0 : 10;
        score -= driver.getContinuousDrivingMinutes() / 10.0;
        if (distance != null && distance != Double.MAX_VALUE) {
            score -= Math.min(30, distance);
        }
        return Math.max(0, score);
    }

    private List<String> reasons(Vehicle vehicle, Driver driver, Double distance) {
        List<String> reasons = new ArrayList<>();
        reasons.add("Vehicle available and GPS online");
        reasons.add("Driver available with safety score " + driver.getSafetyScore());
        if (distance != null && distance != Double.MAX_VALUE) {
            reasons.add("Distance to start: " + Math.round(distance * 10.0) / 10.0 + " km");
        }
        if (vehicle.getInspectionExpiredAt() != null) {
            reasons.add("Inspection valid until " + vehicle.getInspectionExpiredAt());
        }
        return reasons;
    }
}
