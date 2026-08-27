package com.safefleet.flood.dto.response;

import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodGeometryType;
import com.safefleet.flood.enums.FloodSource;
import com.safefleet.flood.enums.FloodStatus;
import com.safefleet.flood.enums.RoadHazardType;

import java.time.LocalDateTime;

public record FloodReportResponse(
        Long id,
        Double lat,
        Double lng,
        String address,
        RoadHazardType hazardType,
        FloodSeverity severity,
        FloodSource source,
        Long reportedByDriverId,
        String reportedByDriverName,
        String imageUrl,
        String clientEventId,
        FloodGeometryType geometryType,
        String geometryJson,
        Double radiusMeters,
        LocalDateTime receivedAt,
        Double confidence,
        FloodStatus status,
        Long verifiedBy,
        LocalDateTime verifiedAt,
        LocalDateTime expiredAt,
        LocalDateTime createdAt
) {
}
