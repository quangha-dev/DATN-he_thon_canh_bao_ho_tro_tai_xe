package com.safefleet.warehouse.entity;

import com.safefleet.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter
@Setter
@Entity
@Table(name = "warehouse_issue_items")
public class WarehouseIssueItem extends BaseEntity {
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "document_id", nullable = false)
    private WarehouseIssueDocument document;
    @Column(name = "line_number", nullable = false)
    private Integer lineNumber;
    @Column(name = "item_code", length = 80)
    private String itemCode;
    @Column(nullable = false, length = 255)
    private String description;
    @Column(length = 255)
    private String specification;
    @Column(nullable = false, length = 40)
    private String unit;
    @Column(name = "requested_quantity", precision = 14, scale = 3)
    private BigDecimal requestedQuantity;
    @Column(name = "issued_quantity", nullable = false, precision = 14, scale = 3)
    private BigDecimal issuedQuantity;
    @Column(name = "returned_quantity", nullable = false, precision = 14, scale = 3)
    private BigDecimal returnedQuantity = BigDecimal.ZERO;
    @Column(name = "delivered_quantity", precision = 14, scale = 3)
    private BigDecimal deliveredQuantity;
    @Column(name = "condition_note", length = 500)
    private String conditionNote;
    @Column(name = "confirmation_note", length = 500)
    private String confirmationNote;
}
