package com.safefleet.device.repository;

import com.safefleet.device.entity.DeviceConnectionLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DeviceConnectionLogRepository extends JpaRepository<DeviceConnectionLog, Long> {

    Page<DeviceConnectionLog> findByDeviceIdOrderByCreatedAtDesc(Long deviceId, Pageable pageable);
}
