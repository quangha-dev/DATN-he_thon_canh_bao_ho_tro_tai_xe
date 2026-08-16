package com.safefleet.mobile.entity;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.common.domain.BaseEntity;
import com.safefleet.mobile.enums.DocumentOcrJobStatus;
import com.safefleet.mobile.enums.PlateReviewStatus;
import com.safefleet.driver.entity.Driver;
import com.safefleet.trip.entity.Trip;
import jakarta.persistence.Basic;
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
import java.time.LocalDate;
import java.math.BigDecimal;

@Getter
@Setter
@Entity
@Table(name = "document_ocr_jobs")
public class DocumentOcrJob extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_user_id", nullable = false)
    private UserAccount owner;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "driver_id")
    private Driver driver;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private DocumentOcrJobStatus status = DocumentOcrJobStatus.QUEUED;

    @Column(name = "original_filename", length = 255)
    private String originalFilename;

    @Column(name = "content_type", nullable = false, length = 80)
    private String contentType;

    @Basic(fetch = FetchType.LAZY)
    @Column(name = "image_data", columnDefinition = "bytea")
    private byte[] imageData;

    @Column(name = "project_address", length = 500)
    private String projectAddress;

    @Column(name = "voucher_date")
    private LocalDate voucherDate;

    @Column(name = "voucher_number", length = 64)
    private String voucherNumber;

    @Column(name = "vehicle_plate", length = 32)
    private String vehiclePlate;

    @Column(name = "expected_vehicle_plate", length = 32)
    private String expectedVehiclePlate;

    @Enumerated(EnumType.STRING)
    @Column(name = "plate_review_status", nullable = false, length = 32)
    private PlateReviewStatus plateReviewStatus = PlateReviewStatus.NOT_CHECKED;

    @Column(name = "plate_review_reason", length = 255)
    private String plateReviewReason;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by_user_id")
    private UserAccount reviewedBy;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    @Column(name = "review_note", length = 500)
    private String reviewNote;

    @Column(name = "driver_name", length = 255)
    private String driverName;

    @Column(name = "trip_count")
    private Integer tripCount;

    @Basic(fetch = FetchType.LAZY)
    @Column(name = "raw_text", columnDefinition = "text")
    private String rawText;

    @Column(name = "project_address_confidence", precision = 5, scale = 4)
    private BigDecimal projectAddressConfidence;

    @Column(name = "voucher_date_confidence", precision = 5, scale = 4)
    private BigDecimal voucherDateConfidence;

    @Column(name = "voucher_number_confidence", precision = 5, scale = 4)
    private BigDecimal voucherNumberConfidence;

    @Column(name = "vehicle_plate_confidence", precision = 5, scale = 4)
    private BigDecimal vehiclePlateConfidence;

    @Column(name = "driver_name_confidence", precision = 5, scale = 4)
    private BigDecimal driverNameConfidence;

    @Column(length = 120)
    private String engine;

    @Column(name = "elapsed_ms")
    private Long elapsedMs;

    @Column(name = "error_message", length = 500)
    private String errorMessage;

    @Column(name = "started_at")
    private LocalDateTime startedAt;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;
}
