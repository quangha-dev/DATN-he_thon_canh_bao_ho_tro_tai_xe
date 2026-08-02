package com.safefleet.report.service;

import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.incident.enums.IncidentStatus;
import com.safefleet.incident.repository.IncidentRepository;
import com.safefleet.report.dto.response.DashboardSummaryResponse;
import com.safefleet.safety.enums.SafetyEventStatus;
import com.safefleet.safety.repository.SafetyEventRepository;
import com.safefleet.trip.enums.TripStatus;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final VehicleRepository vehicleRepository;
    private final DriverRepository driverRepository;
    private final TripRepository tripRepository;
    private final SafetyEventRepository safetyEventRepository;
    private final IncidentRepository incidentRepository;

    @Transactional(readOnly = true)
    public DashboardSummaryResponse summary() {
        Map<String, Long> vehicles = Arrays.stream(VehicleStatus.values())
                .collect(Collectors.toMap(Enum::name, status -> vehicleRepository.countByDeletedFalseAndStatus(status)));
        Map<String, Long> drivers = Arrays.stream(DriverStatus.values())
                .collect(Collectors.toMap(Enum::name, status -> driverRepository.countByDeletedFalseAndStatus(status)));
        Map<String, Long> trips = Arrays.stream(TripStatus.values())
                .collect(Collectors.toMap(Enum::name, status -> tripRepository.countByDeletedFalseAndStatus(status)));
        return new DashboardSummaryResponse(
                vehicleRepository.countByDeletedFalse(),
                vehicles,
                driverRepository.countByDeletedFalse(),
                drivers,
                tripRepository.countByDeletedFalse(),
                trips,
                safetyEventRepository.countByStatusIn(List.of(
                        SafetyEventStatus.NEW,
                        SafetyEventStatus.ACKNOWLEDGED,
                        SafetyEventStatus.PROCESSING
                )),
                incidentRepository.countByStatusIn(List.of(
                        IncidentStatus.OPEN,
                        IncidentStatus.ACCEPTED,
                        IncidentStatus.PROCESSING,
                        IncidentStatus.ESCALATED
                ))
        );
    }
}
