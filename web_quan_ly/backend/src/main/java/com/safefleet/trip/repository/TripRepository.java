package com.safefleet.trip.repository;

import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.enums.TripStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface TripRepository extends JpaRepository<Trip, Long>, JpaSpecificationExecutor<Trip> {

    Optional<Trip> findByTripCode(String tripCode);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select trip from Trip trip where trip.id = :id")
    Optional<Trip> findByIdForUpdate(@Param("id") Long id);

    Optional<Trip> findFirstByDeletedFalseAndDriverIdAndIdNotAndStatusInOrderByActualStartTimeAsc(
            Long driverId,
            Long excludedTripId,
            List<TripStatus> statuses);

    Optional<Trip> findFirstByDeletedFalseAndVehicleIdAndIdNotAndStatusInOrderByActualStartTimeAsc(
            Long vehicleId,
            Long excludedTripId,
            List<TripStatus> statuses);

    long countByDeletedFalse();

    long countByDeletedFalseAndStatus(TripStatus status);

    long countByDeletedFalseAndDriverId(Long driverId);

    long countByDeletedFalseAndVehicleId(Long vehicleId);

    Page<Trip> findByDeletedFalseAndVehicleIdOrderByCreatedAtDesc(Long vehicleId, Pageable pageable);

    Page<Trip> findByDeletedFalseAndDriverIdOrderByCreatedAtDesc(Long driverId, Pageable pageable);

    List<Trip> findByDeletedFalseAndDriverIdAndPlannedStartTimeBetweenOrderByPlannedStartTimeAsc(
            Long driverId,
            LocalDateTime from,
            LocalDateTime to);

    @Query("""
            select t from Trip t
            where t.deleted = false
              and t.driver.id = :driverId
              and (
                    (t.plannedStartTime >= :from and t.plannedStartTime < :to)
                 or (t.actualStartTime >= :from and t.actualStartTime < :to)
                 or (t.actualEndTime >= :from and t.actualEndTime < :to)
                 or t.status in :activeStatuses
              )
            order by coalesce(t.actualStartTime, t.plannedStartTime, t.createdAt) asc
            """)
    List<Trip> findMobileDaySchedule(
            @Param("driverId") Long driverId,
            @Param("from") LocalDateTime from,
            @Param("to") LocalDateTime to,
            @Param("activeStatuses") List<TripStatus> activeStatuses);

    List<Trip> findByDeletedFalseAndDriverIdAndStatusInOrderByPlannedStartTimeAsc(
            Long driverId,
            List<TripStatus> statuses);

    @Query("""
            select t from Trip t
            where t.deleted = false
              and t.plannedStartTime >= :from
              and t.plannedStartTime < :to
            """)
    List<Trip> findPlannedBetween(@Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

    @Query("""
            select t from Trip t
            left join fetch t.vehicle
            where t.deleted = false
              and t.driver.id = :driverId
              and t.status in :statuses
            order by coalesce(t.actualStartTime, t.plannedStartTime, t.createdAt) desc
            """)
    List<Trip> findDriverTripsWithoutDate(
            @Param("driverId") Long driverId,
            @Param("statuses") List<TripStatus> statuses,
            Pageable pageable);

    @Query("""
            select t from Trip t
            left join fetch t.vehicle
            where t.deleted = false
              and t.driver.id = :driverId
              and t.status in :statuses
              and coalesce(t.actualStartTime, t.plannedStartTime, t.createdAt) >= :from
            order by coalesce(t.actualStartTime, t.plannedStartTime, t.createdAt) desc
            """)
    List<Trip> findDriverTripsFrom(
            @Param("driverId") Long driverId,
            @Param("statuses") List<TripStatus> statuses,
            @Param("from") LocalDateTime from,
            Pageable pageable);

    @Query("""
            select t from Trip t
            left join fetch t.vehicle
            where t.deleted = false
              and t.driver.id = :driverId
              and t.status in :statuses
              and coalesce(t.actualEndTime, t.actualStartTime, t.plannedStartTime, t.createdAt) < :to
            order by coalesce(t.actualStartTime, t.plannedStartTime, t.createdAt) desc
            """)
    List<Trip> findDriverTripsTo(
            @Param("driverId") Long driverId,
            @Param("statuses") List<TripStatus> statuses,
            @Param("to") LocalDateTime to,
            Pageable pageable);

    @Query("""
            select t from Trip t
            left join fetch t.vehicle
            where t.deleted = false
              and t.driver.id = :driverId
              and t.status in :statuses
              and coalesce(t.actualStartTime, t.plannedStartTime, t.createdAt) >= :from
              and coalesce(t.actualEndTime, t.actualStartTime, t.plannedStartTime, t.createdAt) < :to
            order by coalesce(t.actualStartTime, t.plannedStartTime, t.createdAt) desc
            """)
    List<Trip> findDriverTripsBetween(
            @Param("driverId") Long driverId,
            @Param("statuses") List<TripStatus> statuses,
            @Param("from") LocalDateTime from,
            @Param("to") LocalDateTime to,
            Pageable pageable);
}
