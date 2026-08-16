package com.safefleet.config;

import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import static org.assertj.core.api.Assertions.assertThat;

class WebSocketAuthorizationPolicyTest {

    @Test
    void backOfficeCanSubscribeOnlyToKnownReadTopics() {
        var dispatcher = authentication("ROLE_DISPATCHER");

        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                dispatcher, StompCommand.SUBSCRIBE, "/topic/vehicles/positions"
        )).isTrue();
        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                dispatcher, StompCommand.SUBSCRIBE, "/topic/telemetry"
        )).isTrue();
        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                dispatcher, StompCommand.SUBSCRIBE, "/topic/vehicles/42/position"
        )).isTrue();
        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                dispatcher, StompCommand.SUBSCRIBE, "/topic/arbitrary"
        )).isFalse();
        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                dispatcher, StompCommand.SEND, "/app/arbitrary"
        )).isFalse();
    }

    @Test
    void rescueTeamCanSubscribeOnlyToIncidentTopic() {
        var rescueTeam = authentication("ROLE_RESCUE_TEAM");

        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                rescueTeam, StompCommand.SUBSCRIBE, "/topic/incidents"
        )).isTrue();
        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                rescueTeam, StompCommand.SUBSCRIBE, "/topic/vehicles/positions"
        )).isFalse();
    }

    @Test
    void driverCannotSubscribeToGlobalFleetTopicsOrUnusedUserQueues() {
        var driver = authentication("ROLE_DRIVER");

        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                driver, StompCommand.SUBSCRIBE, "/topic/vehicles/positions"
        )).isFalse();
        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                driver, StompCommand.SUBSCRIBE, "/topic/notifications"
        )).isFalse();
        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                driver, StompCommand.SUBSCRIBE, "/user/queue/notifications"
        )).isFalse();
    }

    @Test
    void permissionsAreUnionedForUsersWithMultipleRoles() {
        var rescueDispatcher = authentication("ROLE_RESCUE_TEAM", "ROLE_DISPATCHER");

        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                rescueDispatcher, StompCommand.SUBSCRIBE, "/topic/incidents"
        )).isTrue();
        assertThat(WebSocketAuthorizationPolicy.isAllowed(
                rescueDispatcher, StompCommand.SUBSCRIBE, "/topic/vehicles/positions"
        )).isTrue();
    }

    private UsernamePasswordAuthenticationToken authentication(String... roles) {
        return new UsernamePasswordAuthenticationToken(
                "test-user",
                null,
                java.util.Arrays.stream(roles).map(SimpleGrantedAuthority::new).toList()
        );
    }
}
