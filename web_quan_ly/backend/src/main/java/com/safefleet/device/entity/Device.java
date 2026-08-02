package com.safefleet.device.entity;

import com.safefleet.common.domain.BaseEntity;
import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.device.enums.DeviceType;
import com.safefleet.vehicle.entity.Vehicle;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
@Entity
@Table(name = "devices")
public class Device extends BaseEntity {

    @Column(name = "device_code", nullable = false, unique = true, length = 50)
    private String deviceCode;

    @Column(nullable = false, length = 120)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private DeviceType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private DeviceStatus status = DeviceStatus.OFFLINE;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicle_id")
    private Vehicle vehicle;

    @Column(length = 20)
    private String phone;

    @Column(name = "serial_number", length = 80)
    private String serialNumber;

    @Column(name = "firmware_version", length = 40)
    private String firmwareVersion;

    @Column(name = "last_seen_at")
    private LocalDateTime lastSeenAt;
}
