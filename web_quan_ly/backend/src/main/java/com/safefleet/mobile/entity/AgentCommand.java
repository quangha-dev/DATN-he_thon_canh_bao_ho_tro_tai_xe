package com.safefleet.mobile.entity;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.common.domain.BaseEntity;
import com.safefleet.driver.entity.Driver;
import com.safefleet.mobile.enums.AgentCommandStatus;
import com.safefleet.mobile.enums.AgentCommandType;
import com.safefleet.mobile.enums.AgentIntent;
import com.safefleet.trip.entity.Trip;
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

@Getter
@Setter
@Entity
@Table(name = "agent_commands")
public class AgentCommand extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private UserAccount user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "driver_id")
    private Driver driver;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    @Enumerated(EnumType.STRING)
    @Column(name = "command_type", nullable = false, length = 30)
    private AgentCommandType commandType = AgentCommandType.TEXT;

    @Column(nullable = false, length = 1000)
    private String transcript;

    @Column(name = "normalized_command", length = 255)
    private String normalizedCommand;

    @Enumerated(EnumType.STRING)
    @Column(name = "interpreted_intent", length = 40)
    private AgentIntent interpretedIntent;

    private Double confidence;

    @Column(name = "requires_confirmation", nullable = false)
    private boolean requiresConfirmation;

    @Column(name = "classification_source", length = 30)
    private String classificationSource;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private AgentCommandStatus status = AgentCommandStatus.RECEIVED;

    @Column(name = "response_text", length = 1000)
    private String responseText;

    @Column(name = "executed_reference_type", length = 40)
    private String executedReferenceType;

    @Column(name = "executed_reference_id")
    private Long executedReferenceId;
}
