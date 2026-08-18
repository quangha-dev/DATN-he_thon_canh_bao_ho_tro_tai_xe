package com.safefleet.trip.service;

import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.exception.ConflictException;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.notification.service.NotificationService;
import com.safefleet.trip.dto.request.TripActionRequest;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.enums.TripStatus;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.trip.repository.TripTimelineRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.repository.VehicleRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TripOperationalConflictTest {

    @Mock
    private TripRepository tripRepository;
    @Mock
    private TripTimelineRepository timelineRepository;
    @Mock
    private VehicleRepository vehicleRepository;
    @Mock
    private DriverRepository driverRepository;
    @Mock
    private UserAccountRepository userAccountRepository;
    @Mock
    private NotificationService notificationService;
    @Mock
    private EntityManager entityManager;

    @InjectMocks
    private TripService tripService;

    @BeforeEach
    void injectPersistenceContext() {
        ReflectionTestUtils.setField(tripService, "entityManager", entityManager);
    }

    @Test
    void startRejectsAnotherTripWhileDriverIsResting() {
        Trip target = trip(10L, "TRIP-NEW", TripStatus.ACCEPTED, 1L, 2L);
        Trip current = trip(11L, "TRIP-ACTIVE", TripStatus.RESTING, 1L, 3L);
        prepareLocks(target);
        when(tripRepository
                .findFirstByDeletedFalseAndDriverIdAndIdNotAndStatusInOrderByActualStartTimeAsc(
                        1L,
                        10L,
                        List.of(TripStatus.IN_PROGRESS, TripStatus.RESTING)
                ))
                .thenReturn(Optional.of(current));

        assertThatThrownBy(() -> tripService.start(10L, new TripActionRequest(null, null)))
                .isInstanceOf(ConflictException.class)
                .hasMessage("Tài xế đang thực hiện chuyến TRIP-ACTIVE; hãy hoàn thành hoặc hủy chuyến đó trước");

        assertThat(target.getStatus()).isEqualTo(TripStatus.ACCEPTED);
        verify(tripRepository, never())
                .findFirstByDeletedFalseAndVehicleIdAndIdNotAndStatusInOrderByActualStartTimeAsc(
                        2L,
                        10L,
                        List.of(TripStatus.IN_PROGRESS, TripStatus.RESTING)
                );
        verify(timelineRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void startRejectsVehicleAlreadyUsedByAnotherDriver() {
        Trip target = trip(20L, "TRIP-NEW", TripStatus.ASSIGNED, 4L, 5L);
        Trip current = trip(21L, "TRIP-VEHICLE-ACTIVE", TripStatus.IN_PROGRESS, 6L, 5L);
        prepareLocks(target);
        when(tripRepository
                .findFirstByDeletedFalseAndDriverIdAndIdNotAndStatusInOrderByActualStartTimeAsc(
                        4L,
                        20L,
                        List.of(TripStatus.IN_PROGRESS, TripStatus.RESTING)
                ))
                .thenReturn(Optional.empty());
        when(tripRepository
                .findFirstByDeletedFalseAndVehicleIdAndIdNotAndStatusInOrderByActualStartTimeAsc(
                        5L,
                        20L,
                        List.of(TripStatus.IN_PROGRESS, TripStatus.RESTING)
                ))
                .thenReturn(Optional.of(current));

        assertThatThrownBy(() -> tripService.start(20L, new TripActionRequest(null, null)))
                .isInstanceOf(ConflictException.class)
                .hasMessage("Xe 30A-000.05 đang được sử dụng cho chuyến TRIP-VEHICLE-ACTIVE; "
                        + "hãy kết thúc chuyến đó trước");

        assertThat(target.getStatus()).isEqualTo(TripStatus.ASSIGNED);
        verify(timelineRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void locksTripDriverAndVehicleBeforeCheckingOperationalConflicts() {
        Trip target = trip(30L, "TRIP-LOCK", TripStatus.ACCEPTED, 7L, 8L);
        prepareLocks(target);
        when(tripRepository
                .findFirstByDeletedFalseAndDriverIdAndIdNotAndStatusInOrderByActualStartTimeAsc(
                        7L,
                        30L,
                        List.of(TripStatus.IN_PROGRESS, TripStatus.RESTING)
                ))
                .thenReturn(Optional.of(trip(31L, "TRIP-CURRENT", TripStatus.IN_PROGRESS, 7L, 9L)));

        assertThatThrownBy(() -> tripService.start(30L, new TripActionRequest(null, null)))
                .isInstanceOf(ConflictException.class);

        InOrder order = inOrder(tripRepository, entityManager, driverRepository, vehicleRepository);
        order.verify(tripRepository).findByIdForUpdate(30L);
        order.verify(entityManager).refresh(target);
        order.verify(driverRepository).findByIdForUpdate(7L);
        order.verify(vehicleRepository).findByIdForUpdate(8L);
        order.verify(tripRepository)
                .findFirstByDeletedFalseAndDriverIdAndIdNotAndStatusInOrderByActualStartTimeAsc(
                        7L,
                        30L,
                        List.of(TripStatus.IN_PROGRESS, TripStatus.RESTING)
                );
    }

    private void prepareLocks(Trip target) {
        when(tripRepository.findByIdForUpdate(target.getId())).thenReturn(Optional.of(target));
        when(driverRepository.findByIdForUpdate(target.getDriver().getId()))
                .thenReturn(Optional.of(target.getDriver()));
        when(vehicleRepository.findByIdForUpdate(target.getVehicle().getId()))
                .thenReturn(Optional.of(target.getVehicle()));
    }

    private Trip trip(Long id, String code, TripStatus status, Long driverId, Long vehicleId) {
        Driver driver = new Driver();
        driver.setId(driverId);
        Vehicle vehicle = new Vehicle();
        vehicle.setId(vehicleId);
        vehicle.setPlateNumber("30A-000.%02d".formatted(vehicleId));

        Trip trip = new Trip();
        trip.setId(id);
        trip.setTripCode(code);
        trip.setStatus(status);
        trip.setDriver(driver);
        trip.setVehicle(vehicle);
        return trip;
    }
}
