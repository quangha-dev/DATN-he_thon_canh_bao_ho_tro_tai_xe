package com.safefleet.report.service;

import com.safefleet.common.exception.NotFoundException;
import com.safefleet.driver.dto.response.DriverResponse;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.mapper.DriverMapper;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.flood.entity.FloodReport;
import com.safefleet.flood.repository.FloodReportRepository;
import com.safefleet.incident.entity.Incident;
import com.safefleet.incident.repository.IncidentRepository;
import com.safefleet.report.dto.response.DailyTripCountResponse;
import com.safefleet.safety.enums.SafetyEventType;
import com.safefleet.safety.repository.SafetyEventRepository;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.dto.response.VehicleResponse;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.mapper.VehicleMapper;
import com.safefleet.vehicle.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ReportService {

    private final VehicleRepository vehicleRepository;
    private final DriverRepository driverRepository;
    private final TripRepository tripRepository;
    private final SafetyEventRepository safetyEventRepository;
    private final FloodReportRepository floodReportRepository;
    private final IncidentRepository incidentRepository;

    @Transactional(readOnly = true)
    public Map<String, Long> vehicleStatus() {
        return Arrays.stream(VehicleStatus.values())
                .collect(Collectors.toMap(Enum::name, status -> vehicleRepository.countByDeletedFalseAndStatus(status)));
    }

    @Transactional(readOnly = true)
    public Map<String, Long> safetyEventsByType() {
        return Arrays.stream(SafetyEventType.values())
                .collect(Collectors.toMap(Enum::name, safetyEventRepository::countByEventType));
    }

    @Transactional(readOnly = true)
    public List<DailyTripCountResponse> tripsByDay(LocalDate from, LocalDate to) {
        LocalDate start = from == null ? LocalDate.now().minusDays(6) : from;
        LocalDate end = to == null ? LocalDate.now() : to;
        return start.datesUntil(end.plusDays(1))
                .map(day -> new DailyTripCountResponse(
                        day,
                        tripRepository.findPlannedBetween(day.atStartOfDay(), day.plusDays(1).atStartOfDay()).size()
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<DriverResponse> highRiskDrivers() {
        return driverRepository.findTop10ByDeletedFalseOrderBySafetyScoreAscTotalAlertsDesc().stream()
                .map(DriverMapper::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> driverReport(Long id) {
        Driver driver = driverRepository.findById(id)
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Driver", id));
        Map<String, Object> report = new LinkedHashMap<>();
        report.put("driver", DriverMapper.toResponse(driver));
        report.put("totalTrips", tripRepository.countByDeletedFalseAndDriverId(id));
        report.put("totalSafetyEvents", safetyEventRepository.countByDriverId(id));
        report.put("safetyScore", driver.getSafetyScore());
        return report;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> vehicleReport(Long id) {
        Vehicle vehicle = vehicleRepository.findById(id)
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", id));
        Map<String, Object> report = new LinkedHashMap<>();
        report.put("vehicle", VehicleMapper.toResponse(vehicle));
        report.put("totalTrips", tripRepository.countByDeletedFalseAndVehicleId(id));
        report.put("totalSafetyEvents", safetyEventRepository.countByVehicleId(id));
        report.put("lastSpeed", vehicle.getLastSpeed());
        return report;
    }

    @Transactional(readOnly = true)
    public Map<String, Map<String, Long>> floodReport() {
        List<FloodReport> reports = floodReportRepository.findAll();
        return Map.of(
                "bySeverity", reports.stream().collect(Collectors.groupingBy(report -> report.getSeverity().name(), Collectors.counting())),
                "byStatus", reports.stream().collect(Collectors.groupingBy(report -> report.getStatus().name(), Collectors.counting()))
        );
    }

    @Transactional(readOnly = true)
    public Map<String, Map<String, Long>> incidentReport() {
        List<Incident> incidents = incidentRepository.findAll().stream()
                .filter(incident -> !incident.isDeleted())
                .toList();
        return Map.of(
                "byType", incidents.stream().collect(Collectors.groupingBy(incident -> incident.getType().name(), Collectors.counting())),
                "byStatus", incidents.stream().collect(Collectors.groupingBy(incident -> incident.getStatus().name(), Collectors.counting()))
        );
    }
}
