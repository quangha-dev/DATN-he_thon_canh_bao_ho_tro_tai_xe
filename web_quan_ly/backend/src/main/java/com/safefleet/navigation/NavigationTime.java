package com.safefleet.navigation;

import com.safefleet.common.exception.BadRequestException;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;

/**
 * Parses the client-supplied moment of a navigation event.
 *
 * <p>Android reports a GPS fix timestamp in UTC, so the app sends an offset-
 * qualified instant. Jackson's lenient {@code LocalDateTime} binding used to
 * strip the trailing {@code Z} and store the UTC wall clock as if it were local
 * time, which left {@code occurred_at} seven hours behind {@code created_at}
 * for the whole fleet. Off-route timing still worked - every timestamp came
 * from the same clock - but any report joining the two columns was wrong.</p>
 *
 * <p>Both shapes are accepted so an older app build keeps working: a value
 * carrying an offset is converted into the server zone, and a naive value is
 * taken as already being server-local.</p>
 */
public final class NavigationTime {

    private NavigationTime() {
    }

    public static LocalDateTime parse(String value) {
        if (value == null || value.isBlank()) {
            return LocalDateTime.now();
        }
        String trimmed = value.trim();
        try {
            return OffsetDateTime.parse(trimmed)
                    .atZoneSameInstant(ZoneId.systemDefault())
                    .toLocalDateTime();
        } catch (DateTimeParseException ignored) {
            // Not offset-qualified; fall through to the other two shapes.
        }
        try {
            return Instant.parse(trimmed).atZone(ZoneId.systemDefault()).toLocalDateTime();
        } catch (DateTimeParseException ignored) {
            // Not an instant either.
        }
        try {
            return LocalDateTime.parse(trimmed);
        } catch (DateTimeParseException exception) {
            throw new BadRequestException("occurredAt không đúng định dạng ISO-8601");
        }
    }
}
