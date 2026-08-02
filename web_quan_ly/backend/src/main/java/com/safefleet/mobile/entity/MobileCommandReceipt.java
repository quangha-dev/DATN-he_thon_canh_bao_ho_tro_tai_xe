package com.safefleet.mobile.entity;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.Lob;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "mobile_command_receipts")
public class MobileCommandReceipt extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private UserAccount user;

    @Column(name = "client_event_id", nullable = false, length = 100)
    private String clientEventId;

    @Column(nullable = false, length = 50)
    private String operation;

    @Column(name = "trip_id")
    private Long tripId;

    @Lob
    @Column(name = "response_json", nullable = false, columnDefinition = "LONGTEXT")
    private String responseJson;
}
