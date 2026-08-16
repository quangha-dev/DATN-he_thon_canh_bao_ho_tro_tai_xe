package com.safefleet.mobile.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.mobile.dto.response.MobileDocumentOcrJobResponse;
import com.safefleet.mobile.entity.DocumentOcrJob;
import com.safefleet.mobile.repository.DocumentOcrJobRepository;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.enums.TripStatus;
import com.safefleet.trip.repository.TripRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

import java.util.LinkedHashMap;
import java.util.Map;
import java.math.BigDecimal;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DocumentOcrJobService {

    private final DocumentOcrJobRepository repository;
    private final UserAccountRepository userRepository;
    private final DriverRepository driverRepository;
    private final TripRepository tripRepository;
    private final DocumentOcrService ocrService;
    private final DocumentOcrJobProcessor processor;

    @Transactional
    public MobileDocumentOcrJobResponse submit(MultipartFile file) {
        DocumentOcrService.UploadedDocument upload = ocrService.readUpload(file);
        UserAccount owner = userRepository.findById(SecurityUtils.currentUserId())
                .orElseThrow(() -> new NotFoundException("User", SecurityUtils.currentUserId()));
        DocumentOcrJob job = new DocumentOcrJob();
        job.setOwner(owner);
        Driver driver = driverRepository.findByUserId(owner.getId()).orElse(null);
        job.setDriver(driver);
        if (driver != null) {
            if (driver.getCurrentVehicle() != null) {
                job.setExpectedVehiclePlate(driver.getCurrentVehicle().getPlateNumber());
            }
            List<Trip> activeTrips = tripRepository
                    .findByDeletedFalseAndDriverIdAndStatusInOrderByPlannedStartTimeAsc(
                            driver.getId(),
                            List.of(TripStatus.ASSIGNED, TripStatus.ACCEPTED,
                                    TripStatus.IN_PROGRESS, TripStatus.RESTING));
            if (!activeTrips.isEmpty()) job.setTrip(activeTrips.get(0));
        }
        job.setContentType(upload.contentType());
        job.setOriginalFilename(upload.originalFilename());
        job.setImageData(upload.bytes());
        DocumentOcrJob saved = repository.saveAndFlush(job);
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                processor.schedule(saved.getId());
            }
        });
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public MobileDocumentOcrJobResponse get(Long id) {
        DocumentOcrJob job = repository
                .findByIdAndOwnerIdAndDeletedFalse(id, SecurityUtils.currentUserId())
                .orElseThrow(() -> new NotFoundException("DocumentOcrJob", id));
        return toResponse(job);
    }

    @Transactional
    public void delete(Long id) {
        DocumentOcrJob job = repository
                .findByIdAndOwnerIdAndDeletedFalse(id, SecurityUtils.currentUserId())
                .orElseThrow(() -> new NotFoundException("DocumentOcrJob", id));
        job.setDeleted(true);
        job.setImageData(null);
        repository.save(job);
    }

    private MobileDocumentOcrJobResponse toResponse(DocumentOcrJob job) {
        Map<String, Double> confidences = new LinkedHashMap<>();
        putConfidence(confidences, "projectAddress", job.getProjectAddressConfidence());
        putConfidence(confidences, "voucherDate", job.getVoucherDateConfidence());
        putConfidence(confidences, "voucherNumber", job.getVoucherNumberConfidence());
        putConfidence(confidences, "vehiclePlate", job.getVehiclePlateConfidence());
        putConfidence(confidences, "driverName", job.getDriverNameConfidence());
        return new MobileDocumentOcrJobResponse(
                job.getId(), job.getStatus(), job.getProjectAddress(),
                job.getVoucherDate(), job.getVoucherNumber(), job.getVehiclePlate(),
                job.getExpectedVehiclePlate(), job.getPlateReviewStatus(), job.getPlateReviewReason(),
                job.getDriverName(), job.getTripCount(), job.getRawText(), confidences, job.getEngine(),
                job.getElapsedMs(), job.getErrorMessage(), job.getCreatedAt(), job.getCompletedAt()
        );
    }

    private static void putConfidence(Map<String, Double> target, String field, BigDecimal value) {
        if (value != null) target.put(field, value.doubleValue());
    }
}
