package com.safefleet.driver.repository;

import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.enums.DriverStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import java.util.List;
import java.util.Optional;

public interface DriverRepository extends JpaRepository<Driver, Long>, JpaSpecificationExecutor<Driver> {

    Optional<Driver> findByUserId(Long userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select driver from Driver driver where driver.id = :id")
    Optional<Driver> findByIdForUpdate(@Param("id") Long id);

    Optional<Driver> findByLicenseNumber(String licenseNumber);

    boolean existsByLicenseNumber(String licenseNumber);

    long countByDeletedFalse();

    long countByDeletedFalseAndStatus(DriverStatus status);

    List<Driver> findByDeletedFalseAndStatus(DriverStatus status);

    List<Driver> findTop10ByDeletedFalseOrderBySafetyScoreAscTotalAlertsDesc();
}
