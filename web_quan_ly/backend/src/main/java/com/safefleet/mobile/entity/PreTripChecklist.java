package com.safefleet.mobile.entity;

import com.safefleet.common.domain.BaseEntity;
import com.safefleet.driver.entity.Driver;
import com.safefleet.trip.entity.Trip;
import com.safefleet.vehicle.entity.Vehicle;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "pre_trip_checklists")
public class PreTripChecklist extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id", nullable = false)
    private Trip trip;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "driver_id", nullable = false)
    private Driver driver;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicle_id")
    private Vehicle vehicle;

    @Column(name = "exterior_checked", nullable = false)
    private boolean exteriorChecked;

    @Column(name = "tires_checked", nullable = false)
    private boolean tiresChecked;

    @Column(name = "brake_checked", nullable = false)
    private boolean brakeChecked;

    @Column(name = "lights_checked", nullable = false)
    private boolean lightsChecked;

    @Column(name = "camera_checked", nullable = false)
    private boolean cameraChecked;

    @Column(name = "gps_checked", nullable = false)
    private boolean gpsChecked;

    @Column(name = "documents_checked", nullable = false)
    private boolean documentsChecked;

    @Column(name = "checklist_json", columnDefinition = "json")
    private String checklistJson;

    @Column(length = 500)
    private String note;
}
