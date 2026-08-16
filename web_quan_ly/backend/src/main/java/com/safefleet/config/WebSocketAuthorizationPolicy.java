package com.safefleet.config;

import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.security.core.Authentication;

import java.util.Set;
import java.util.regex.Pattern;

final class WebSocketAuthorizationPolicy {

    private static final Set<String> BACK_OFFICE_ROLES = Set.of(
            "ROLE_ADMIN",
            "ROLE_FLEET_MANAGER",
            "ROLE_DISPATCHER",
            "ROLE_SAFETY_OFFICER"
    );
    private static final Set<String> GLOBAL_TOPICS = Set.of(
            "/topic/telemetry",
            "/topic/vehicles/positions",
            "/topic/safety-events",
            "/topic/incidents",
            "/topic/flood-reports",
            "/topic/notifications"
    );
    private static final Pattern VEHICLE_POSITION_TOPIC =
            Pattern.compile("^/topic/vehicles/[1-9][0-9]*/position$");

    private WebSocketAuthorizationPolicy() {
    }

    static boolean isAllowed(Authentication authentication, StompCommand command, String destination) {
        if (authentication == null || !authentication.isAuthenticated() || destination == null) {
            return false;
        }
        if (StompCommand.SEND.equals(command)) {
            return false;
        }
        if (!StompCommand.SUBSCRIBE.equals(command)) {
            return true;
        }
        if (destination.startsWith("/user/queue/")) {
            return false;
        }
        boolean rescueTeam = authentication.getAuthorities().stream()
                .anyMatch(authority -> "ROLE_RESCUE_TEAM".equals(authority.getAuthority()));
        boolean backOffice = authentication.getAuthorities().stream()
                .anyMatch(authority -> BACK_OFFICE_ROLES.contains(authority.getAuthority()));
        return (rescueTeam && "/topic/incidents".equals(destination))
                || (backOffice && (GLOBAL_TOPICS.contains(destination)
                || VEHICLE_POSITION_TOPIC.matcher(destination).matches()));
    }
}
