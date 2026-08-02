package com.safefleet.device.repository;

import com.safefleet.device.entity.Device;
import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.device.enums.DeviceType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.Optional;

public interface DeviceRepository extends JpaRepository<Device, Long>, JpaSpecificationExecutor<Device> {

    Optional<Device> findByDeviceCode(String deviceCode);

    boolean existsByDeviceCode(String deviceCode);

    Page<Device> findByDeletedFalseAndTypeAndStatus(DeviceType type, DeviceStatus status, Pageable pageable);
}
