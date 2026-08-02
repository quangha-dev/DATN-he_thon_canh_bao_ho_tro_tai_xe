package com.safefleet.flood.entity;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.common.domain.BaseEntity;
import com.safefleet.driver.entity.Driver;
import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodSource;
import com.safefleet.flood.enums.FloodStatus;
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
@Table(name = "flood_reports")
public class FloodReport extends BaseEntity {

    @Column(nullable = false)
    private Double lat;

    @Column(nullable = false)
    private Double lng;

    @Column(length = 255)
    private String address;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private FloodSeverity severity;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private FloodSource source;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reported_by_driver_id")
    private Driver reportedByDriver;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "client_event_id", length = 100)
    private String clientEventId;

    @Column(name = "received_at", nullable = false, updatable = false)
    private LocalDateTime receivedAt = LocalDateTime.now();

    private Double confidence;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private FloodStatus status = FloodStatus.UNVERIFIED;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "verified_by")
    private UserAccount verifiedBy;

    @Column(name = "verified_at")
    private LocalDateTime verifiedAt;

    @Column(name = "expired_at")
    private LocalDateTime expiredAt;
}
