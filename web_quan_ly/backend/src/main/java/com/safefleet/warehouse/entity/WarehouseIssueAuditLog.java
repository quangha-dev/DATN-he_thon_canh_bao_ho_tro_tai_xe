package com.safefleet.warehouse.entity;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.warehouse.enums.WarehouseIssueStatus;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter
@Setter
@Entity
@Table(name = "warehouse_issue_audit_logs")
public class WarehouseIssueAuditLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "document_id", nullable = false)
    private WarehouseIssueDocument document;
    @Column(nullable = false, length = 50)
    private String action;
    @Enumerated(EnumType.STRING)
    @Column(name = "from_status", length = 30)
    private WarehouseIssueStatus fromStatus;
    @Enumerated(EnumType.STRING)
    @Column(name = "to_status", length = 30)
    private WarehouseIssueStatus toStatus;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "actor_user_id")
    private UserAccount actor;
    @Column(name = "actor_name", length = 150)
    private String actorName;
    @Column(length = 500)
    private String note;
    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
}
