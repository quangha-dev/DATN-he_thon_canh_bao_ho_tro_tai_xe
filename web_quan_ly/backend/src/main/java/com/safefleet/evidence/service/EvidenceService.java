package com.safefleet.evidence.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.evidence.dto.EvidenceContent;
import com.safefleet.evidence.dto.EvidenceResponse;
import com.safefleet.evidence.entity.SafetyEventEvidence;
import com.safefleet.evidence.repository.SafetyEventEvidenceRepository;
import com.safefleet.evidence.storage.EvidenceStorage;
import com.safefleet.incident.entity.Incident;
import com.safefleet.incident.service.IncidentService;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.safety.entity.SafetyEvent;
import com.safefleet.safety.service.SafetyEventService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class EvidenceService {

    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
            "image/jpeg",
            "image/png",
            "image/webp"
    );

    private final SafetyEventEvidenceRepository evidenceRepository;
    private final SafetyEventService safetyEventService;
    private final IncidentService incidentService;
    private final UserAccountRepository userAccountRepository;
    private final DriverRepository driverRepository;
    private final EvidenceStorage evidenceStorage;

    @Value("${app.evidence.max-size-bytes:8388608}")
    private long maxSizeBytes;

    @Transactional
    public EvidenceResponse upload(Long safetyEventId,
                                   Long incidentId,
                                   LocalDateTime capturedAt,
                                   MultipartFile file) {
        if ((safetyEventId == null) == (incidentId == null)) {
            throw new BadRequestException("Phải truyền đúng một safetyEventId hoặc incidentId");
        }
        validateFile(file);

        SafetyEvent safetyEvent = safetyEventId == null ? null : safetyEventService.findEvent(safetyEventId);
        Incident incident = incidentId == null ? null : incidentService.findIncident(incidentId);
        assertCanAccess(safetyEvent, incident);

        String extension = extensionFor(file.getContentType());
        LocalDate today = LocalDate.now();
        String objectKey = "%04d/%02d/%02d/%s%s".formatted(
                today.getYear(),
                today.getMonthValue(),
                today.getDayOfMonth(),
                UUID.randomUUID(),
                extension
        );
        try {
            evidenceStorage.store(objectKey, file);
        } catch (IOException exception) {
            throw new BadRequestException("Không thể lưu file evidence");
        }

        try {
            SafetyEventEvidence evidence = new SafetyEventEvidence();
            evidence.setSafetyEvent(safetyEvent);
            evidence.setIncident(incident);
            evidence.setUploadedBy(currentUser());
            evidence.setObjectKey(objectKey.replace('\\', '/'));
            evidence.setOriginalFilename(safeFilename(file.getOriginalFilename()));
            evidence.setContentType(file.getContentType());
            evidence.setSizeBytes(file.getSize());
            evidence.setSha256(sha256(file));
            evidence.setCapturedAt(capturedAt);
            return toResponse(evidenceRepository.save(evidence));
        } catch (RuntimeException exception) {
            try {
                evidenceStorage.delete(objectKey);
            } catch (IOException ignored) {
                // Database failure remains primary; orphan cleanup is best effort.
            }
            throw exception;
        }
    }

    @Transactional(readOnly = true)
    public EvidenceResponse metadata(Long id) {
        SafetyEventEvidence evidence = findEvidence(id);
        assertCanAccess(evidence.getSafetyEvent(), evidence.getIncident());
        return toResponse(evidence);
    }

    @Transactional(readOnly = true)
    public EvidenceContent content(Long id) {
        SafetyEventEvidence evidence = findEvidence(id);
        assertCanAccess(evidence.getSafetyEvent(), evidence.getIncident());
        try {
            return new EvidenceContent(
                    toResponse(evidence),
                    evidenceStorage.load(evidence.getObjectKey())
            );
        } catch (FileNotFoundException exception) {
            throw new NotFoundException("Evidence file", id);
        } catch (IOException exception) {
            throw new BadRequestException("Không thể đọc file evidence");
        }
    }

    private void validateFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("File evidence không được để trống");
        }
        if (file.getSize() > maxSizeBytes) {
            throw new BadRequestException("File evidence vượt quá giới hạn 8 MB");
        }
        if (!ALLOWED_CONTENT_TYPES.contains(file.getContentType())) {
            throw new BadRequestException("Evidence chỉ chấp nhận JPEG, PNG hoặc WebP");
        }
        String detected;
        try (InputStream input = file.getInputStream()) {
            detected = detectImageType(input.readNBytes(16));
        } catch (IOException exception) {
            throw new BadRequestException("Không thể đọc file evidence");
        }
        if (!file.getContentType().equals(detected)) {
            throw new BadRequestException("Nội dung file không khớp MIME khai báo");
        }
    }

    private String detectImageType(byte[] header) {
        if (header.length >= 3
                && (header[0] & 0xff) == 0xff
                && (header[1] & 0xff) == 0xd8
                && (header[2] & 0xff) == 0xff) {
            return "image/jpeg";
        }
        if (header.length >= 8
                && header[0] == (byte) 0x89
                && header[1] == 0x50
                && header[2] == 0x4e
                && header[3] == 0x47
                && header[4] == 0x0d
                && header[5] == 0x0a
                && header[6] == 0x1a
                && header[7] == 0x0a) {
            return "image/png";
        }
        if (header.length >= 12
                && header[0] == 'R'
                && header[1] == 'I'
                && header[2] == 'F'
                && header[3] == 'F'
                && header[8] == 'W'
                && header[9] == 'E'
                && header[10] == 'B'
                && header[11] == 'P') {
            return "image/webp";
        }
        return "";
    }

    private String sha256(MultipartFile file) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (InputStream input = file.getInputStream();
                 DigestInputStream digestInput = new DigestInputStream(input, digest)) {
                digestInput.transferTo(java.io.OutputStream.nullOutputStream());
            }
            return HexFormat.of().formatHex(digest.digest());
        } catch (IOException | NoSuchAlgorithmException exception) {
            throw new BadRequestException("Không thể kiểm tra checksum evidence");
        }
    }

    private void assertCanAccess(SafetyEvent safetyEvent, Incident incident) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return;
        }
        Driver driver = driverRepository.findByUserId(SecurityUtils.currentUserId())
                .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy hồ sơ tài xế"));
        Long ownerDriverId = safetyEvent != null
                ? safetyEvent.getDriver() == null ? null : safetyEvent.getDriver().getId()
                : incident.getDriver() == null ? null : incident.getDriver().getId();
        if (!driver.getId().equals(ownerDriverId)) {
            throw new ForbiddenActionException("Không được truy cập evidence của tài xế khác");
        }
    }

    private UserAccount currentUser() {
        return userAccountRepository.findById(SecurityUtils.currentUserId())
                .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy người dùng"));
    }

    private SafetyEventEvidence findEvidence(Long id) {
        return evidenceRepository.findByIdAndDeletedFalse(id)
                .orElseThrow(() -> new NotFoundException("Evidence", id));
    }

    private EvidenceResponse toResponse(SafetyEventEvidence evidence) {
        return new EvidenceResponse(
                evidence.getId(),
                evidence.getSafetyEvent() == null ? null : evidence.getSafetyEvent().getId(),
                evidence.getIncident() == null ? null : evidence.getIncident().getId(),
                evidence.getOriginalFilename(),
                evidence.getContentType(),
                evidence.getSizeBytes(),
                evidence.getSha256(),
                evidence.getCapturedAt(),
                evidence.getCreatedAt(),
                "/api/v1/evidence/" + evidence.getId() + "/content"
        );
    }

    private String safeFilename(String filename) {
        if (filename == null || filename.isBlank()) {
            return "evidence";
        }
        String normalized = java.nio.file.Path.of(filename).getFileName().toString()
                .replaceAll("[\\r\\n\\u0000]", "_");
        return normalized.length() <= 255 ? normalized : normalized.substring(0, 255);
    }

    private String extensionFor(String contentType) {
        return switch (contentType) {
            case "image/jpeg" -> ".jpg";
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            default -> "";
        };
    }
}
