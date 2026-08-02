package com.safefleet.location.dto.response;

public record LocationSuggestionResponse(
        String id,
        String name,
        String address,
        Double lat,
        Double lng,
        String source
) {
}
