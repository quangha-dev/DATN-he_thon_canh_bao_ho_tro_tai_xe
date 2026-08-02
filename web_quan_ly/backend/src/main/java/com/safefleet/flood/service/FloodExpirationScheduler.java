package com.safefleet.flood.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class FloodExpirationScheduler {

    private final JdbcTemplate jdbcTemplate;

    @Scheduled(
            fixedDelayString = "${app.flood.expiration-scan-ms:60000}",
            initialDelayString = "${app.flood.expiration-initial-delay-ms:15000}"
    )
    @Transactional
    public void expireReports() {
        int updated = jdbcTemplate.update("""
                UPDATE flood_reports
                SET status = 'EXPIRED', updated_at = CURRENT_TIMESTAMP(6)
                WHERE status IN ('UNVERIFIED', 'VERIFIED')
                  AND expired_at IS NOT NULL
                  AND expired_at <= CURRENT_TIMESTAMP(6)
                  AND deleted = FALSE
                """);
        if (updated > 0) {
            log.info("Expired {} stale flood report(s)", updated);
        }
    }
}
