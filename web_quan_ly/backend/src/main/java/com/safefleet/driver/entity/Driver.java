package com.safefleet.driver.entity;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.common.domain.BaseEntity;
import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.vehicle.entity.Vehicle;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "drivers")
public class Driver extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private UserAccount user;

    @Column(name = "full_name", nullable = false, length = 150)
    private String fullName;

    @Column(nullable = false, length = 20)
    private String phone;

    @Column(length = 120)
    private String email;

    @Column(length = 255)
    private String address;

    @Column(name = "license_number", nullable = false, unique = true, length = 50)
    private String licenseNumber;

    @Column(name = "license_class", nullable = false, length = 20)
    private String licenseClass;

    @Column(name = "license_expired_at", nullable = false)
    private LocalDate licenseExpiredAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private DriverStatus status = DriverStatus.AVAILABLE;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "current_vehicle_id")
    private Vehicle currentVehicle;

    @Column(name = "safety_score", nullable = false)
    private Integer safetyScore = 100;

    @Column(name = "driving_time_today_minutes", nullable = false)
    private Integer drivingTimeTodayMinutes = 0;

    @Column(name = "continuous_driving_minutes", nullable = false)
    private Integer continuousDrivingMinutes = 0;

    @Column(name = "total_trips", nullable = false)
    private Integer totalTrips = 0;

    @Column(name = "total_alerts", nullable = false)
    private Integer totalAlerts = 0;
}
