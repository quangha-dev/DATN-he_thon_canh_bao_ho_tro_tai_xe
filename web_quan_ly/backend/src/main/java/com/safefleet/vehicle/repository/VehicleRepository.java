package com.safefleet.vehicle.repository;

import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.enums.VehicleStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import java.util.List;
import java.util.Optional;

public interface VehicleRepository extends JpaRepository<Vehicle, Long>, JpaSpecificationExecutor<Vehicle> {

    Optional<Vehicle> findByPlateNumber(String plateNumber);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select vehicle from Vehicle vehicle where vehicle.id = :id")
    Optional<Vehicle> findByIdForUpdate(@Param("id") Long id);

    boolean existsByPlateNumber(String plateNumber);

    long countByDeletedFalse();

    long countByDeletedFalseAndStatus(VehicleStatus status);

    List<Vehicle> findByDeletedFalseAndStatus(VehicleStatus status);
}
