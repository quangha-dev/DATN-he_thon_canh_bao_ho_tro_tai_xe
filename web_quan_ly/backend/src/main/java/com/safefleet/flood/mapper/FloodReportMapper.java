package com.safefleet.flood.mapper;

import com.safefleet.flood.dto.response.FloodReportResponse;
import com.safefleet.flood.entity.FloodReport;

public final class FloodReportMapper {

    private FloodReportMapper() {
    }

    public static FloodReportResponse toResponse(FloodReport report) {
        return new FloodReportResponse(
                report.getId(),
                report.getLat(),
                report.getLng(),
                report.getAddress(),
                report.getSeverity(),
                report.getSource(),
                report.getReportedByDriver() == null ? null : report.getReportedByDriver().getId(),
                report.getReportedByDriver() == null ? null : report.getReportedByDriver().getFullName(),
                report.getImageUrl(),
                report.getClientEventId(),
                report.getReceivedAt(),
                report.getConfidence(),
                report.getStatus(),
                report.getVerifiedBy() == null ? null : report.getVerifiedBy().getId(),
                report.getVerifiedAt(),
                report.getExpiredAt(),
                report.getCreatedAt()
        );
    }
}
