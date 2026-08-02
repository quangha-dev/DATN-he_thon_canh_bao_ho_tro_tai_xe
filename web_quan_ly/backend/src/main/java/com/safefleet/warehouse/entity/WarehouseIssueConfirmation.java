package com.safefleet.warehouse.entity;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.common.domain.BaseEntity;
import com.safefleet.warehouse.enums.ConfirmationRole;
import com.safefleet.warehouse.enums.ConfirmationStatus;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter
@Setter
@Entity
@Table(name = "warehouse_issue_confirmations")
public class WarehouseIssueConfirmation extends BaseEntity {
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "document_id", nullable = false)
    private WarehouseIssueDocument document;
    @Enumerated(EnumType.STRING)
    @Column(name = "role_type", nullable = false, length = 30)
    private ConfirmationRole role;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private ConfirmationStatus status;
    @Column(name = "signer_name", nullable = false, length = 150)
    private String signerName;
    @Column(name = "signer_phone", length = 20)
    private String signerPhone;
    @Column(name = "signed_at")
    private LocalDateTime signedAt;
    private Double lat;
    private Double lng;
    @Column(name = "evidence_url", length = 500)
    private String evidenceUrl;
    @Column(length = 500)
    private String note;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_user_id")
    private UserAccount createdBy;
}
