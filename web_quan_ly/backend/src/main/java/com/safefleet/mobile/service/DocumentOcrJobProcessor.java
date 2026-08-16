package com.safefleet.mobile.service;

import com.safefleet.mobile.dto.response.MobileDocumentOcrResponse;
import com.safefleet.mobile.entity.DocumentOcrJob;
import com.safefleet.mobile.enums.DocumentOcrJobStatus;
import com.safefleet.mobile.enums.PlateReviewStatus;
import com.safefleet.mobile.repository.DocumentOcrJobRepository;
import com.safefleet.notification.enums.NotificationType;
import com.safefleet.notification.service.NotificationService;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.task.TaskExecutor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDateTime;
import java.math.BigDecimal;
import java.util.List;

@Component
public class DocumentOcrJobProcessor {

    private final DocumentOcrJobRepository repository;
    private final DocumentOcrService ocrService;
    private final NotificationService notificationService;
    private final TransactionTemplate transactions;
    private final TaskExecutor executor;

    public DocumentOcrJobProcessor(
            DocumentOcrJobRepository repository,
            DocumentOcrService ocrService,
            NotificationService notificationService,
            TransactionTemplate transactions,
            @Qualifier("ocrTaskExecutor") TaskExecutor executor) {
        this.repository = repository;
        this.ocrService = ocrService;
        this.notificationService = notificationService;
        this.transactions = transactions;
        this.executor = executor;
    }

    public void schedule(Long jobId) {
        executor.execute(() -> process(jobId));
    }

    @EventListener(ApplicationReadyEvent.class)
    public void recoverIncompleteJobs() {
        List<Long> jobIds = transactions.execute(status -> repository
                .findByStatusInAndDeletedFalse(List.of(
                        DocumentOcrJobStatus.QUEUED,
                        DocumentOcrJobStatus.PROCESSING
                ))
                .stream()
                .filter(job -> job.getImageData() != null && job.getImageData().length > 0)
                .peek(job -> {
                    job.setStatus(DocumentOcrJobStatus.QUEUED);
                    job.setStartedAt(null);
                    repository.save(job);
                })
                .map(DocumentOcrJob::getId)
                .toList());
        if (jobIds != null) jobIds.forEach(this::schedule);
    }

    private void process(Long jobId) {
        WorkItem work = transactions.execute(status -> {
            DocumentOcrJob job = repository.findById(jobId).orElse(null);
            if (job == null || job.isDeleted() || job.getStatus() != DocumentOcrJobStatus.QUEUED) return null;
            job.setStatus(DocumentOcrJobStatus.PROCESSING);
            job.setStartedAt(LocalDateTime.now());
            repository.save(job);
            return new WorkItem(
                    job.getOwner().getId(),
                    job.getImageData(),
                    job.getContentType(),
                    job.getOriginalFilename()
            );
        });
        if (work == null) return;

        try {
            MobileDocumentOcrResponse result = ocrService.recognize(
                    new DocumentOcrService.UploadedDocument(
                            work.bytes(), work.contentType(), work.originalFilename()
                    )
            );
            Boolean shouldNotify = transactions.execute(status -> {
                DocumentOcrJob job = repository.findById(jobId).orElseThrow();
                if (job.isDeleted()) return null;
                job.setStatus(DocumentOcrJobStatus.COMPLETED);
                job.setProjectAddress(result.projectAddress());
                job.setVoucherDate(result.voucherDate());
                job.setVoucherNumber(result.voucherNumber());
                job.setVehiclePlate(result.vehiclePlate());
                job.setDriverName(result.driverName());
                job.setTripCount(result.tripCount());
                job.setRawText(result.rawText());
                job.setProjectAddressConfidence(confidence(result, "project_address"));
                job.setVoucherDateConfidence(confidence(result, "voucher_date"));
                job.setVoucherNumberConfidence(confidence(result, "voucher_number"));
                job.setVehiclePlateConfidence(confidence(result, "vehicle_plate"));
                job.setDriverNameConfidence(confidence(result, "driver_name"));
                job.setEngine(result.engine());
                job.setElapsedMs(result.elapsedMs());
                job.setCompletedAt(LocalDateTime.now());
                String expectedPlate = normalizePlate(job.getExpectedVehiclePlate());
                String recognizedPlate = normalizePlate(result.vehiclePlate());
                if (expectedPlate.isBlank()) {
                    job.setStatus(DocumentOcrJobStatus.AWAITING_REVIEW);
                    job.setPlateReviewStatus(PlateReviewStatus.REVIEW_REQUIRED);
                    job.setPlateReviewReason("Tài khoản chưa được gán biển số xe cố định");
                } else if (recognizedPlate.isBlank()) {
                    job.setStatus(DocumentOcrJobStatus.AWAITING_REVIEW);
                    job.setPlateReviewStatus(PlateReviewStatus.REVIEW_REQUIRED);
                    job.setPlateReviewReason("OCR không đọc được biển số trên phiếu");
                } else if (!expectedPlate.equals(recognizedPlate)) {
                    job.setStatus(DocumentOcrJobStatus.AWAITING_REVIEW);
                    job.setPlateReviewStatus(PlateReviewStatus.REVIEW_REQUIRED);
                    job.setPlateReviewReason("Biển số OCR không khớp xe cố định của tài xế");
                } else {
                    job.setStatus(DocumentOcrJobStatus.COMPLETED);
                    job.setPlateReviewStatus(PlateReviewStatus.MATCHED);
                    job.setPlateReviewReason(null);
                    job.setImageData(null);
                }
                repository.save(job);
                return job.getStatus() == DocumentOcrJobStatus.AWAITING_REVIEW;
            });
            if (shouldNotify == null) {
                return;
            } else if (Boolean.TRUE.equals(shouldNotify)) {
                notificationService.createForUser(
                        work.ownerId(), NotificationType.SYSTEM,
                        "Phiếu đang chờ xác nhận biển số",
                        "Biển số trên phiếu chưa khớp với xe được giao. Quản lý sẽ kiểm tra trước khi ghi nhận.",
                        "DOCUMENT_OCR_JOB", jobId
                );
            } else {
                notificationService.createForUser(
                        work.ownerId(), NotificationType.SYSTEM,
                        "OCR phiếu đã hoàn thành",
                        "Dữ liệu trên phiếu đã được nhận dạng và biển số đã khớp.",
                        "DOCUMENT_OCR_JOB", jobId
                );
            }
        } catch (Exception exception) {
            String message = exception.getMessage() == null
                    ? "Không thể nhận dạng phiếu"
                    : exception.getMessage();
            if (message.length() > 500) message = message.substring(0, 500);
            String finalMessage = message;
            Boolean shouldNotify = transactions.execute(status -> {
                DocumentOcrJob job = repository.findById(jobId).orElseThrow();
                if (job.isDeleted()) return false;
                job.setStatus(DocumentOcrJobStatus.FAILED);
                job.setErrorMessage(finalMessage);
                job.setCompletedAt(LocalDateTime.now());
                job.setImageData(null);
                repository.save(job);
                return true;
            });
            if (Boolean.TRUE.equals(shouldNotify)) {
                notificationService.createForUser(
                        work.ownerId(), NotificationType.SYSTEM,
                        "OCR phiếu chưa thành công",
                        "Không nhận dạng được phiếu. Hãy mở app để thử gửi lại.",
                        "DOCUMENT_OCR_JOB", jobId
                );
            }
        }
    }

    private record WorkItem(Long ownerId, byte[] bytes, String contentType, String originalFilename) {
    }

    private static BigDecimal confidence(MobileDocumentOcrResponse result, String field) {
        Double value = result.fieldConfidences().get(field);
        return value == null ? null : BigDecimal.valueOf(value);
    }

    private static String normalizePlate(String value) {
        return value == null ? "" : value.toUpperCase().replaceAll("[^A-Z0-9]", "");
    }
}
