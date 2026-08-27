package com.safefleet.telemetry.entity;

import com.safefleet.driver.entity.Driver;
import com.safefleet.telemetry.enums.GpsStatus;
import com.safefleet.trip.entity.Trip;
import com.safefleet.vehicle.entity.Vehicle;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
@Entity
@Table(name = "telemetry_logs")
public class TelemetryLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicle_id", nullable = false)
    private Vehicle vehicle;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "driver_id")
    private Driver driver;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    @Column(nullable = false)
    private Double lat;

    @Column(nullable = false)
    private Double lng;

    private Double speed;

    private Double heading;

    @Column(name = "battery_level")
    private Integer batteryLevel;

    @Column(name = "gps_accuracy_meters")
    private Double gpsAccuracyMeters;

    @Enumerated(EnumType.STRING)
    @Column(name = "gps_status", nullable = false, length = 30)
    private GpsStatus gpsStatus = GpsStatus.GOOD;

    @Column(name = "position_accepted", nullable = false)
    private boolean positionAccepted = true;

    @Column(name = "client_event_id", length = 100)
    private String clientEventId;

    @Column(name = "recorded_at")
    private LocalDateTime recordedAt;

    @Column(name = "received_at", nullable = false)
    private LocalDateTime receivedAt = LocalDateTime.now();

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
