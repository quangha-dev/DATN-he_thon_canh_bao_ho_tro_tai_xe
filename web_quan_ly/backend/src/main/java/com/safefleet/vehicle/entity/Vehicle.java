package com.safefleet.vehicle.entity;

import com.safefleet.common.domain.BaseEntity;
import com.safefleet.device.entity.Device;
import com.safefleet.driver.entity.Driver;
import com.safefleet.vehicle.enums.FuelType;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.enums.VehicleType;
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

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter
@Setter
@Entity
@Table(name = "vehicles")
public class Vehicle extends BaseEntity {

    @Column(name = "plate_number", nullable = false, unique = true, length = 30)
    private String plateNumber;

    @Enumerated(EnumType.STRING)
    @Column(name = "vehicle_type", nullable = false, length = 30)
    private VehicleType vehicleType;

    @Column(length = 80)
    private String brand;

    @Column(length = 80)
    private String model;

    @Column(name = "manufacture_year")
    private Integer year;

    @Column(name = "load_capacity", precision = 10, scale = 2)
    private BigDecimal loadCapacity;

    @Column(name = "height_meters", precision = 5, scale = 2)
    private BigDecimal heightMeters;

    @Column(name = "width_meters", precision = 5, scale = 2)
    private BigDecimal widthMeters;

    @Column(name = "length_meters", precision = 5, scale = 2)
    private BigDecimal lengthMeters;

    @Column(name = "gross_weight_tons", precision = 7, scale = 2)
    private BigDecimal grossWeightTons;

    @Column(name = "axle_load_tons", precision = 6, scale = 2)
    private BigDecimal axleLoadTons;

    @Column(name = "axle_count")
    private Integer axleCount;

    @Column(name = "top_speed_kph", precision = 6, scale = 2)
    private BigDecimal topSpeedKph;

    @Column(name = "hazardous_goods", nullable = false)
    private boolean hazardousGoods;

    @Column(name = "seat_count")
    private Integer seatCount;

    @Enumerated(EnumType.STRING)
    @Column(name = "fuel_type", length = 30)
    private FuelType fuelType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private VehicleStatus status = VehicleStatus.AVAILABLE;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "current_driver_id")
    private Driver currentDriver;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "gps_device_id")
    private Device gpsDevice;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "camera_device_id")
    private Device cameraDevice;

    @Column(name = "inspection_expired_at")
    private LocalDate inspectionExpiredAt;

    @Column(name = "insurance_expired_at")
    private LocalDate insuranceExpiredAt;

    @Column(name = "last_lat")
    private Double lastLat;

    @Column(name = "last_lng")
    private Double lastLng;

    @Column(name = "last_speed")
    private Double lastSpeed;

    @Column(name = "last_updated_at")
    private LocalDateTime lastUpdatedAt;
}
