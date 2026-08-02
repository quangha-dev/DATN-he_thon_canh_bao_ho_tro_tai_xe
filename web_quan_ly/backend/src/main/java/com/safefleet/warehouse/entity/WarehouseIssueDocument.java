package com.safefleet.warehouse.entity;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.common.domain.BaseEntity;
import com.safefleet.driver.entity.Driver;
import com.safefleet.trip.entity.Trip;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.warehouse.enums.WarehouseIssueStatus;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Getter
@Setter
@Entity
@Table(name = "warehouse_issue_documents")
public class WarehouseIssueDocument extends BaseEntity {
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id", unique = true)
    private Trip trip;
    @Column(name = "issue_number", nullable = false, unique = true, length = 50)
    private String issueNumber;
    @Column(name = "issue_date", nullable = false)
    private LocalDate issueDate;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private WarehouseIssueStatus status = WarehouseIssueStatus.DRAFT;
    @Column(name = "document_version", nullable = false)
    private Integer documentVersion = 1;
    @Column(name = "company_name", length = 200)
    private String companyName;
    @Column(name = "company_address", length = 255)
    private String companyAddress;
    @Column(name = "issue_reason", length = 500)
    private String issueReason;
    @Column(name = "warehouse_name", nullable = false, length = 150)
    private String warehouseName;
    @Column(name = "warehouse_location", length = 150)
    private String warehouseLocation;
    @Column(name = "project_name", nullable = false, length = 200)
    private String projectName;
    @Column(name = "work_item", length = 200)
    private String workItem;
    @Column(name = "recipient_name", nullable = false, length = 150)
    private String recipientName;
    @Column(name = "recipient_phone", length = 20)
    private String recipientPhone;
    @Column(name = "delivery_address", length = 255)
    private String deliveryAddress;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "prepared_by_user_id")
    private UserAccount preparedBy;
    @Column(name = "prepared_by_name", length = 150)
    private String preparedByName;
    @Column(name = "delivery_person_name", length = 150)
    private String deliveryPersonName;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "driver_id")
    private Driver driver;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicle_id")
    private Vehicle vehicle;
    @Column(name = "quantity_in_words", length = 500)
    private String quantityInWords;
    @Column(length = 1000)
    private String notes;
    @Column(name = "issued_at")
    private LocalDateTime issuedAt;
    @Column(name = "completed_at")
    private LocalDateTime completedAt;
    @OneToMany(mappedBy = "document", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("lineNumber asc")
    private List<WarehouseIssueItem> items = new ArrayList<>();
    @OneToMany(mappedBy = "document", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("createdAt asc")
    private List<WarehouseIssueConfirmation> confirmations = new ArrayList<>();

    public void replaceItems(List<WarehouseIssueItem> nextItems) {
        items.clear();
        nextItems.forEach(item -> {
            item.setDocument(this);
            items.add(item);
        });
    }
}
