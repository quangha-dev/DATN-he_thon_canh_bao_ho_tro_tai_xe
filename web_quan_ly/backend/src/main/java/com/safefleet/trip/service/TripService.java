package com.safefleet.trip.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.common.util.CodeGenerator;
import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.trip.dto.request.AssignTripRequest;
import com.safefleet.trip.dto.request.CancelTripRequest;
import com.safefleet.trip.dto.request.CreateTripRequest;
import com.safefleet.trip.dto.request.TripActionRequest;
import com.safefleet.trip.dto.response.TripResponse;
import com.safefleet.trip.dto.response.TripTimelineResponse;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.entity.TripTimeline;
import com.safefleet.trip.enums.RiskLevel;
import com.safefleet.trip.enums.TripStatus;
import com.safefleet.trip.mapper.TripMapper;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.trip.repository.TripTimelineRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.repository.VehicleRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class TripService {

    private final TripRepository tripRepository;
    private final TripTimelineRepository timelineRepository;
    private final VehicleRepository vehicleRepository;
    private final DriverRepository driverRepository;
    private final UserAccountRepository userAccountRepository;

    @Transactional(readOnly = true)
    public PageResponse<TripResponse> search(TripStatus status,
                                             Long vehicleId,
                                             Long driverId,
                                             LocalDate fromDate,
                                             LocalDate toDate,
                                             Pageable pageable) {
        Long driverScope = driverId;
        if (SecurityUtils.hasRole("DRIVER")) {
            driverScope = driverRepository.findByUserId(SecurityUtils.currentUserId())
                    .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy hồ sơ tài xế"))
                    .getId();
        }
        Long scopedDriverId = driverScope;
        Specification<Trip> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isFalse(root.get("deleted")));
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (vehicleId != null) {
                predicates.add(cb.equal(root.get("vehicle").get("id"), vehicleId));
            }
            if (scopedDriverId != null) {
                predicates.add(cb.equal(root.get("driver").get("id"), scopedDriverId));
            }
            if (fromDate != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("plannedStartTime"), fromDate.atStartOfDay()));
            }
            if (toDate != null) {
                predicates.add(cb.lessThan(root.get("plannedStartTime"), toDate.plusDays(1).atStartOfDay()));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.from(tripRepository.findAll(spec, pageable).map(TripMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public TripResponse get(Long id) {
        Trip trip = findTrip(id);
        assertTripCanAccess(trip);
        return TripMapper.toResponse(trip);
    }

    @Transactional
    public TripResponse create(CreateTripRequest request) {
        validateSchedule(request.plannedStartTime(), request.estimatedEndTime());
        Trip trip = new Trip();
        trip.setTripCode(CodeGenerator.code("TRIP"));
        trip.setStartLocation(request.startLocation());
        trip.setStartLat(request.startLat());
        trip.setStartLng(request.startLng());
        trip.setEndLocation(request.endLocation());
        trip.setEndLat(request.endLat());
        trip.setEndLng(request.endLng());
        trip.setWaypoints(request.waypoints());
        trip.setPlannedRoute(request.plannedRoute());
        trip.setPlannedStartTime(request.plannedStartTime());
        trip.setEstimatedEndTime(request.estimatedEndTime());
        trip.setRiskLevel(request.riskLevel() == null ? RiskLevel.LOW : request.riskLevel());

        if (request.vehicleId() != null && request.driverId() != null) {
            Vehicle vehicle = findVehicle(request.vehicleId());
            Driver driver = findDriver(request.driverId());
            validateAssignable(vehicle, driver);
            trip.setVehicle(vehicle);
            trip.setDriver(driver);
            trip.setStatus(TripStatus.ASSIGNED);
            vehicle.setCurrentDriver(driver);
            driver.setCurrentVehicle(vehicle);
        }

        Trip saved = tripRepository.save(trip);
        addTimeline(saved, "CREATED", "Trip created");
        if (saved.getStatus() == TripStatus.ASSIGNED) {
            addTimeline(saved, "ASSIGNED", "Trip assigned at creation");
        }
        return TripMapper.toResponse(saved);
    }

    @Transactional
    public TripResponse assign(Long id, AssignTripRequest request) {
        Trip trip = findTrip(id);
        if (trip.getStatus() != TripStatus.DRAFT && trip.getStatus() != TripStatus.CANCELLED) {
            throw new BadRequestException("Chỉ có thể giao chuyến nháp hoặc đã hủy");
        }
        Vehicle vehicle = findVehicle(request.vehicleId());
        Driver driver = findDriver(request.driverId());
        validateAssignable(vehicle, driver);
        trip.setVehicle(vehicle);
        trip.setDriver(driver);
        trip.setStatus(TripStatus.ASSIGNED);
        trip.setProgress(0);
        trip.setCancelReason(null);
        vehicle.setCurrentDriver(driver);
        driver.setCurrentVehicle(vehicle);
        addTimeline(trip, "ASSIGNED", "Assigned to driver and vehicle");
        return TripMapper.toResponse(trip);
    }

    @Transactional
    public TripResponse accept(Long id, TripActionRequest request) {
        Trip trip = findTrip(id);
        assertTripCanAccess(trip);
        requireStatus(trip, TripStatus.ASSIGNED);
        trip.setStatus(TripStatus.ACCEPTED);
        addTimeline(trip, "ACCEPTED", request.note());
        return TripMapper.toResponse(trip);
    }

    @Transactional
    public TripResponse start(Long id, TripActionRequest request) {
        Trip trip = findTrip(id);
        assertTripCanAccess(trip);
        if (trip.getStatus() != TripStatus.ACCEPTED && trip.getStatus() != TripStatus.ASSIGNED) {
            throw new BadRequestException("Chuyến đi chưa sẵn sàng để bắt đầu");
        }
        trip.setStatus(TripStatus.IN_PROGRESS);
        trip.setActualStartTime(LocalDateTime.now());
        trip.setProgress(Math.max(trip.getProgress(), 5));
        if (trip.getVehicle() != null) {
            trip.getVehicle().setStatus(VehicleStatus.RUNNING);
        }
        if (trip.getDriver() != null) {
            trip.getDriver().setStatus(DriverStatus.DRIVING);
        }
        addTimeline(trip, "STARTED", request.note());
        return TripMapper.toResponse(trip);
    }

    @Transactional
    public TripResponse pause(Long id, TripActionRequest request) {
        Trip trip = findTrip(id);
        assertTripCanAccess(trip);
        requireStatus(trip, TripStatus.IN_PROGRESS);
        trip.setStatus(TripStatus.RESTING);
        if (trip.getVehicle() != null) {
            trip.getVehicle().setStatus(VehicleStatus.RESTING);
        }
        if (trip.getDriver() != null) {
            trip.getDriver().setStatus(DriverStatus.RESTING);
        }
        addTimeline(trip, "PAUSED", request.note());
        return TripMapper.toResponse(trip);
    }

    @Transactional
    public TripResponse resume(Long id, TripActionRequest request) {
        Trip trip = findTrip(id);
        assertTripCanAccess(trip);
        requireStatus(trip, TripStatus.RESTING);
        trip.setStatus(TripStatus.IN_PROGRESS);
        if (trip.getVehicle() != null) {
            trip.getVehicle().setStatus(VehicleStatus.RUNNING);
        }
        if (trip.getDriver() != null) {
            trip.getDriver().setStatus(DriverStatus.DRIVING);
        }
        addTimeline(trip, "RESUMED", request.note());
        return TripMapper.toResponse(trip);
    }

    @Transactional
    public TripResponse complete(Long id, TripActionRequest request) {
        Trip trip = findTrip(id);
        assertTripCanAccess(trip);
        if (trip.getStatus() != TripStatus.IN_PROGRESS && trip.getStatus() != TripStatus.RESTING) {
            throw new BadRequestException("Chuyến đi chưa thể hoàn thành");
        }
        trip.setStatus(TripStatus.COMPLETED);
        trip.setProgress(100);
        trip.setActualEndTime(LocalDateTime.now());
        if (trip.getVehicle() != null) {
            trip.getVehicle().setStatus(VehicleStatus.AVAILABLE);
        }
        if (trip.getDriver() != null) {
            trip.getDriver().setStatus(DriverStatus.AVAILABLE);
            trip.getDriver().setTotalTrips(trip.getDriver().getTotalTrips() + 1);
        }
        addTimeline(trip, "COMPLETED", request.note());
        return TripMapper.toResponse(trip);
    }

    @Transactional
    public TripResponse cancel(Long id, CancelTripRequest request) {
        Trip trip = findTrip(id);
        if (trip.getStatus() == TripStatus.COMPLETED) {
            throw new BadRequestException("Không thể hủy chuyến đã hoàn thành");
        }
        trip.setStatus(TripStatus.CANCELLED);
        trip.setCancelReason(request.reason());
        if (trip.getVehicle() != null) {
            trip.getVehicle().setStatus(VehicleStatus.AVAILABLE);
        }
        if (trip.getDriver() != null) {
            trip.getDriver().setStatus(DriverStatus.AVAILABLE);
        }
        addTimeline(trip, "CANCELLED", request.reason());
        return TripMapper.toResponse(trip);
    }

    @Transactional(readOnly = true)
    public List<TripTimelineResponse> timeline(Long id) {
        Trip trip = findTrip(id);
        assertTripCanAccess(trip);
        return timelineRepository.findByTripIdOrderByCreatedAtAsc(id).stream()
                .map(TripMapper::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public PageResponse<TripResponse> tripsByVehicle(Long vehicleId, Pageable pageable) {
        return PageResponse.from(tripRepository.findByDeletedFalseAndVehicleIdOrderByCreatedAtDesc(vehicleId, pageable)
                .map(TripMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public PageResponse<TripResponse> tripsByDriver(Long driverId, Pageable pageable) {
        if (SecurityUtils.hasRole("DRIVER")) {
            Driver driver = driverRepository.findByUserId(SecurityUtils.currentUserId())
                    .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy hồ sơ tài xế"));
            if (!driver.getId().equals(driverId)) {
                throw new ForbiddenActionException("Tài xế chỉ được xem chuyến của chính mình");
            }
        }
        return PageResponse.from(tripRepository.findByDeletedFalseAndDriverIdOrderByCreatedAtDesc(driverId, pageable)
                .map(TripMapper::toResponse));
    }

    public Trip findTrip(Long id) {
        return tripRepository.findById(id)
                .filter(trip -> !trip.isDeleted())
                .orElseThrow(() -> new NotFoundException("Trip", id));
    }

    public void validateAssignable(Vehicle vehicle, Driver driver) {
        if (driver.getCurrentVehicle() != null
                && !driver.getCurrentVehicle().getId().equals(vehicle.getId())) {
            throw new BadRequestException("Tài xế đã được gán cố định cho xe khác");
        }
        if (vehicle.getCurrentDriver() != null
                && !vehicle.getCurrentDriver().getId().equals(driver.getId())) {
            throw new BadRequestException("Xe đã được gán cố định cho tài xế khác");
        }
        if (vehicle.getStatus() != VehicleStatus.AVAILABLE && vehicle.getStatus() != VehicleStatus.RESTING) {
            throw new BadRequestException("Xe không khả dụng");
        }
        if (vehicle.getInspectionExpiredAt() != null && vehicle.getInspectionExpiredAt().isBefore(LocalDate.now())) {
            throw new BadRequestException("Đăng kiểm xe đã hết hạn");
        }
        if (vehicle.getGpsDevice() == null || vehicle.getGpsDevice().getStatus() != DeviceStatus.ONLINE) {
            throw new BadRequestException("GPS của xe không online");
        }
        if (driver.getStatus() != DriverStatus.AVAILABLE && driver.getStatus() != DriverStatus.RESTING) {
            throw new BadRequestException("Tài xế không khả dụng");
        }
        if (driver.getContinuousDrivingMinutes() >= 210) {
            throw new BadRequestException("Tài xế gần vượt quá giờ lái");
        }
        if (driver.getSafetyScore() < 50) {
            throw new BadRequestException("Điểm an toàn tài xế quá thấp");
        }
    }

    private void requireStatus(Trip trip, TripStatus required) {
        if (trip.getStatus() != required) {
            throw new BadRequestException("Trạng thái chuyến không hợp lệ");
        }
    }

    private void validateSchedule(LocalDateTime plannedStartTime, LocalDateTime estimatedEndTime) {
        if (plannedStartTime == null || estimatedEndTime == null) {
            throw new BadRequestException("Bắt buộc nhập thời gian khởi hành và kết thúc dự kiến");
        }
        if (plannedStartTime.isBefore(LocalDateTime.now().minusMinutes(1))) {
            throw new BadRequestException("Thời gian đi không được ở quá khứ");
        }
        if (!estimatedEndTime.isAfter(plannedStartTime)) {
            throw new BadRequestException("Thời gian đến phải sau thời gian đi");
        }
    }

    private Vehicle findVehicle(Long id) {
        return vehicleRepository.findById(id)
                .filter(vehicle -> !vehicle.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", id));
    }

    private Driver findDriver(Long id) {
        return driverRepository.findById(id)
                .filter(driver -> !driver.isDeleted())
                .orElseThrow(() -> new NotFoundException("Driver", id));
    }

    private void addTimeline(Trip trip, String action, String note) {
        TripTimeline timeline = new TripTimeline();
        timeline.setTrip(trip);
        timeline.setAction(action);
        timeline.setActor(currentActor());
        timeline.setNote(note);
        timelineRepository.save(timeline);
    }

    private UserAccount currentActor() {
        try {
            return userAccountRepository.findById(SecurityUtils.currentUserId()).orElse(null);
        } catch (RuntimeException ignored) {
            return null;
        }
    }

    private void assertTripCanAccess(Trip trip) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return;
        }
        if (trip.getDriver() == null || trip.getDriver().getUser() == null
                || !trip.getDriver().getUser().getId().equals(SecurityUtils.currentUserId())) {
            throw new ForbiddenActionException("Tài xế chỉ được xem chuyến của chính mình");
        }
    }
}
