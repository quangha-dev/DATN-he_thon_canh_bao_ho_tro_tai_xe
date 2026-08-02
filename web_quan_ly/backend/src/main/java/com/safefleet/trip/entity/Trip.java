package com.safefleet.trip.entity;

import com.safefleet.common.domain.BaseEntity;
import com.safefleet.driver.entity.Driver;
import com.safefleet.trip.enums.RiskLevel;
import com.safefleet.trip.enums.TripStatus;
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
@Table(name = "trips")
public class Trip extends BaseEntity {

    @Column(name = "trip_code", nullable = false, unique = true, length = 50)
    private String tripCode;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicle_id")
    private Vehicle vehicle;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "driver_id")
    private Driver driver;

    @Column(name = "start_location", nullable = false, length = 255)
    private String startLocation;

    @Column(name = "start_lat")
    private Double startLat;

    @Column(name = "start_lng")
    private Double startLng;

    @Column(name = "end_location", nullable = false, length = 255)
    private String endLocation;

    @Column(name = "end_lat")
    private Double endLat;

    @Column(name = "end_lng")
    private Double endLng;

    @Column(name = "waypoints_json", columnDefinition = "json")
    private String waypoints;

    @Column(name = "planned_route_json", columnDefinition = "json")
    private String plannedRoute;

    @Column(name = "actual_route_json", columnDefinition = "json")
    private String actualRoute;

    @Column(name = "planned_start_time")
    private LocalDateTime plannedStartTime;

    @Column(name = "actual_start_time")
    private LocalDateTime actualStartTime;

    @Column(name = "estimated_end_time")
    private LocalDateTime estimatedEndTime;

    @Column(name = "actual_end_time")
    private LocalDateTime actualEndTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private TripStatus status = TripStatus.DRAFT;

    @Column(nullable = false)
    private Integer progress = 0;

    @Enumerated(EnumType.STRING)
    @Column(name = "risk_level", nullable = false, length = 30)
    private RiskLevel riskLevel = RiskLevel.LOW;

    @Column(name = "cancel_reason", length = 255)
    private String cancelReason;
}
