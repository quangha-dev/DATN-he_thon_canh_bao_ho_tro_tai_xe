package com.safefleet.infrastructure.security;

import com.safefleet.common.exception.TooManyRequestsException;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class ActionRateLimiter {

    private final Map<String, ArrayDeque<Instant>> requests = new ConcurrentHashMap<>();

    public void check(Long userId, String action, int maximumRequests, Duration window) {
        String key = userId + ":" + action;
        Instant now = Instant.now();
        Instant cutoff = now.minus(window);
        ArrayDeque<Instant> bucket = requests.computeIfAbsent(key, ignored -> new ArrayDeque<>());
        synchronized (bucket) {
            while (!bucket.isEmpty() && bucket.peekFirst().isBefore(cutoff)) {
                bucket.removeFirst();
            }
            if (bucket.size() >= maximumRequests) {
                throw new TooManyRequestsException(
                        "Quá nhiều yêu cầu " + action + ", vui lòng thử lại sau"
                );
            }
            bucket.addLast(now);
        }
        if (requests.size() > 10_000) {
            requests.entrySet().removeIf(entry -> {
                ArrayDeque<Instant> value = entry.getValue();
                synchronized (value) {
                    return value.isEmpty() || value.peekLast().isBefore(cutoff);
                }
            });
        }
    }
}
