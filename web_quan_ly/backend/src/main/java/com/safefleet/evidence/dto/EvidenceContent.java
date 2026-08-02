package com.safefleet.evidence.dto;

import org.springframework.core.io.Resource;

public record EvidenceContent(
        EvidenceResponse metadata,
        Resource resource
) {
}
