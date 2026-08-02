package com.safefleet.safety.entity;

import com.safefleet.common.domain.BaseEntity;
import com.safefleet.driver.entity.Driver;
import com.safefleet.trip.entity.Trip;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "driver_work_logs")
public class DriverWorkLog extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "driver_id", nullable = false)
    private Driver driver;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(name = "driving_minutes", nullable = false)
    private Integer drivingMinutes = 0;

    @Column(name = "rest_minutes", nullable = false)
    private Integer restMinutes = 0;

    @Column(length = 500)
    private String note;
}
