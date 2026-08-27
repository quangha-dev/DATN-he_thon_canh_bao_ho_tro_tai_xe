package com.safefleet.infrastructure.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Set;

@Slf4j
@Component
@RequiredArgsConstructor
public class MutationAuditFilter extends OncePerRequestFilter {

    private static final Set<String> MUTATING_METHODS = Set.of("POST", "PUT", "PATCH", "DELETE");
    private final JdbcTemplate jdbcTemplate;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !MUTATING_METHODS.contains(request.getMethod())
                || !request.getRequestURI().startsWith("/api/v1/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            filterChain.doFilter(request, response);
        } finally {
            writeAudit(request, response);
        }
    }

    private void writeAudit(HttpServletRequest request, HttpServletResponse response) {
        try {
            String path = request.getRequestURI();
            String relative = path.substring("/api/v1/".length());
            String[] segments = relative.split("/");
            String targetType = segments.length == 0 ? "api" : truncate(segments[0], 80);
            Long targetId = firstNumericSegment(segments);
            Long actorId = currentActorId();
            String action = truncate(request.getMethod() + " " + path + " [" + response.getStatus() + "]", 120);
            jdbcTemplate.update("""
                    INSERT INTO audit_logs (
                        actor_id, action, target_type, target_id,
                        ip_address, user_agent, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    actorId,
                    action,
                    targetType,
                    targetId,
                    truncate(request.getRemoteAddr(), 80),
                    truncate(request.getHeader("User-Agent"), 255),
                    LocalDateTime.now());
        } catch (Exception exception) {
            // Audit không được làm hỏng nghiệp vụ chính; cảnh báo này phải được
            // đưa vào hệ thống log tập trung và alert trong production.
            log.error("Unable to persist mutation audit event", exception);
        }
    }

    private Long currentActorId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof UserPrincipal principal) {
            return principal.getId();
        }
        return null;
    }

    private Long firstNumericSegment(String[] segments) {
        for (String segment : segments) {
            try {
                return Long.valueOf(segment);
            } catch (NumberFormatException ignored) {
                // Continue with the next path segment.
            }
        }
        return null;
    }

    private String truncate(String value, int maximum) {
        if (value == null) return null;
        return value.length() <= maximum ? value : value.substring(0, maximum);
    }
}
