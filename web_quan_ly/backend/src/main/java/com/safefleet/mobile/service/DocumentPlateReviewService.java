package com.safefleet.mobile.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.mobile.dto.response.DocumentPlateReviewResponse;
import com.safefleet.mobile.entity.DocumentOcrJob;
import com.safefleet.mobile.enums.DocumentOcrJobStatus;
import com.safefleet.mobile.enums.PlateReviewStatus;
import com.safefleet.mobile.repository.DocumentOcrJobRepository;
import com.safefleet.notification.enums.NotificationType;
import com.safefleet.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class DocumentPlateReviewService {

    private final DocumentOcrJobRepository repository;
    private final UserAccountRepository userRepository;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public PageResponse<DocumentPlateReviewResponse> list(PlateReviewStatus status, Pageable pageable) {
        return PageResponse.from(repository
                .findByDeletedFalseAndPlateReviewStatusOrderByCreatedAtDesc(status, pageable)
                .map(this::toResponse));
    }

    @Transactional(readOnly = true)
    public DocumentPlateReviewResponse get(Long id) {
        return toResponse(find(id));
    }

    @Transactional(readOnly = true)
    public ReviewImage image(Long id) {
        DocumentOcrJob job = find(id);
        if (job.getImageData() == null || job.getImageData().length == 0) {
            throw new NotFoundException("DocumentReviewImage", id);
        }
        return new ReviewImage(job.getImageData(), job.getContentType(), job.getOriginalFilename());
    }

    @Transactional
    public DocumentPlateReviewResponse approve(Long id, String note) {
        DocumentOcrJob job = pending(id);
        applyDecision(job, PlateReviewStatus.APPROVED, note);
        job.setStatus(DocumentOcrJobStatus.COMPLETED);
        job.setErrorMessage(null);
        DocumentOcrJob saved = repository.saveAndFlush(job);
        notificationService.createForUser(
                saved.getOwner().getId(), NotificationType.SYSTEM,
                "Quản lý đã xác nhận phiếu",
                "Phiếu lệch biển số đã được chấp nhận và sẽ được ghi nhận trên ứng dụng.",
                "DOCUMENT_OCR_JOB", saved.getId());
        return toResponse(saved);
    }

    @Transactional
    public DocumentPlateReviewResponse reject(Long id, String note) {
        DocumentOcrJob job = pending(id);
        applyDecision(job, PlateReviewStatus.REJECTED, note);
        job.setStatus(DocumentOcrJobStatus.FAILED);
        job.setErrorMessage("Quản lý từ chối phiếu do biển số không khớp");
        DocumentOcrJob saved = repository.saveAndFlush(job);
        notificationService.createForUser(
                saved.getOwner().getId(), NotificationType.SYSTEM,
                "Phiếu không được xác nhận",
                "Quản lý đã từ chối phiếu do biển số không khớp với xe được giao.",
                "DOCUMENT_OCR_JOB", saved.getId());
        return toResponse(saved);
    }

    private void applyDecision(DocumentOcrJob job, PlateReviewStatus decision, String note) {
        UserAccount reviewer = userRepository.findById(SecurityUtils.currentUserId())
                .orElseThrow(() -> new NotFoundException("User", SecurityUtils.currentUserId()));
        job.setPlateReviewStatus(decision);
        job.setReviewedBy(reviewer);
        job.setReviewedAt(LocalDateTime.now());
        job.setReviewNote(note == null || note.isBlank() ? null : note.trim());
    }

    private DocumentOcrJob pending(Long id) {
        DocumentOcrJob job = find(id);
        if (job.getPlateReviewStatus() != PlateReviewStatus.REVIEW_REQUIRED
                || job.getStatus() != DocumentOcrJobStatus.AWAITING_REVIEW) {
            throw new BadRequestException("Phiếu không còn ở trạng thái chờ xác nhận");
        }
        return job;
    }

    private DocumentOcrJob find(Long id) {
        return repository.findById(id)
                .filter(job -> !job.isDeleted())
                .orElseThrow(() -> new NotFoundException("DocumentOcrJob", id));
    }

    private DocumentPlateReviewResponse toResponse(DocumentOcrJob job) {
        return new DocumentPlateReviewResponse(
                job.getId(),
                job.getDriver() == null ? null : job.getDriver().getId(),
                job.getDriver() == null ? job.getOwner().getFullName() : job.getDriver().getFullName(),
                job.getTrip() == null ? null : job.getTrip().getId(),
                job.getTrip() == null ? null : job.getTrip().getTripCode(),
                job.getExpectedVehiclePlate(), job.getVehiclePlate(),
                job.getPlateReviewStatus(), job.getPlateReviewReason(), job.getReviewNote(),
                job.getReviewedBy() == null ? null : job.getReviewedBy().getId(),
                job.getReviewedBy() == null ? null : job.getReviewedBy().getFullName(),
                job.getReviewedAt(), job.getVoucherNumber(), job.getVoucherDate(),
                job.getProjectAddress(), job.getOriginalFilename(),
                job.getPlateReviewStatus() == PlateReviewStatus.REVIEW_REQUIRED
                        || job.getPlateReviewStatus() == PlateReviewStatus.APPROVED
                        || job.getPlateReviewStatus() == PlateReviewStatus.REJECTED
                        ? "/api/v1/document-reviews/" + job.getId() + "/image" : null,
                job.getCreatedAt(), job.getCompletedAt());
    }

    public record ReviewImage(byte[] bytes, String contentType, String filename) {
    }
}
