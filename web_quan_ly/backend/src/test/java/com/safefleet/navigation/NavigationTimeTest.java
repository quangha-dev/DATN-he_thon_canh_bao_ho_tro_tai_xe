package com.safefleet.navigation;

import com.safefleet.common.exception.BadRequestException;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class NavigationTimeTest {

    @Test
    void convertsAnOffsetQualifiedDeviceTimestampIntoServerLocalTime() {
        // Android reports a GPS fix in UTC. Jackson's lenient LocalDateTime
        // binding used to drop the trailing Z, storing the UTC wall clock as if
        // it were Asia/Ho_Chi_Minh and leaving occurred_at hours behind
        // created_at for the whole fleet.
        LocalDateTime parsed = NavigationTime.parse("2026-08-26T03:20:00.000Z");

        LocalDateTime expected = ZonedDateTime
                .parse("2026-08-26T03:20:00.000Z")
                .withZoneSameInstant(ZoneId.systemDefault())
                .toLocalDateTime();
        assertThat(parsed).isEqualTo(expected);
    }

    @Test
    void acceptsAnExplicitOffsetOtherThanUtc() {
        LocalDateTime parsed = NavigationTime.parse("2026-08-26T10:20:00+07:00");

        LocalDateTime expected = ZonedDateTime
                .parse("2026-08-26T10:20:00+07:00")
                .withZoneSameInstant(ZoneId.systemDefault())
                .toLocalDateTime();
        assertThat(parsed).isEqualTo(expected);
    }

    @Test
    void keepsAcceptingTheNaiveShapeOlderAppBuildsStillSend() {
        assertThat(NavigationTime.parse("2026-08-26T10:20:00"))
                .isEqualTo(LocalDateTime.of(2026, 8, 26, 10, 20));
    }

    @Test
    void fallsBackToNowWhenTheDeviceOmitsTheTimestamp() {
        LocalDateTime before = LocalDateTime.now().minusSeconds(5);
        LocalDateTime after = LocalDateTime.now().plusSeconds(5);

        assertThat(NavigationTime.parse(null)).isBetween(before, after);
        assertThat(NavigationTime.parse("  ")).isBetween(before, after);
    }

    @Test
    void rejectsAValueThatIsNotATimestampAtAll() {
        assertThatThrownBy(() -> NavigationTime.parse("hôm qua"))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("ISO-8601");
    }
}
