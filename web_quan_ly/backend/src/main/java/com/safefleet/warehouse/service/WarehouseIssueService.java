package com.safefleet.warehouse.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.common.util.CodeGenerator;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.warehouse.dto.request.WarehouseIssueConfirmationRequest;
import com.safefleet.warehouse.dto.request.WarehouseIssueItemRequest;
import com.safefleet.warehouse.dto.request.WarehouseIssueRequest;
import com.safefleet.warehouse.dto.response.*;
import com.safefleet.warehouse.entity.*;
import com.safefleet.warehouse.enums.*;
import com.safefleet.warehouse.repository.WarehouseIssueAuditLogRepository;
import com.safefleet.warehouse.repository.WarehouseIssueDocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class WarehouseIssueService {
    private final WarehouseIssueDocumentRepository documentRepository;
    private final WarehouseIssueAuditLogRepository auditRepository;
    private final TripRepository tripRepository;
    private final UserAccountRepository userRepository;

    @Transactional
    public WarehouseIssueResponse create(WarehouseIssueRequest request) {
        WarehouseIssueDocument document = new WarehouseIssueDocument();
        document.setIssueNumber(resolveIssueNumber(request.issueNumber()));
        attachTrip(document, request.tripId());
        apply(document, request);
        document.setPreparedBy(currentUser());
        document.setPreparedByName(document.getPreparedBy().getFullName());
        WarehouseIssueDocument saved = documentRepository.save(document);
        addAudit(saved, "CREATED", null, WarehouseIssueStatus.DRAFT, "Tạo phiếu nháp");
        return response(saved);
    }

    @Transactional
    public WarehouseIssueResponse update(Long id, WarehouseIssueRequest request) {
        WarehouseIssueDocument document = find(id);
        requireDraft(document);
        if (request.issueNumber() != null
                && !request.issueNumber().isBlank()
                && !document.getIssueNumber().equalsIgnoreCase(request.issueNumber().trim())) {
            if (documentRepository.existsByIssueNumberAndDeletedFalse(request.issueNumber().trim())) {
                throw new BadRequestException("Số phiếu xuất kho đã tồn tại");
            }
            document.setIssueNumber(request.issueNumber().trim());
        }
        apply(document, request);
        document.setDocumentVersion(document.getDocumentVersion() + 1);
        addAudit(document, "UPDATED", document.getStatus(), document.getStatus(), "Cập nhật phiếu nháp");
        return response(document);
    }

    @Transactional(readOnly = true)
    public WarehouseIssueResponse get(Long id) {
        WarehouseIssueDocument document = find(id);
        assertCanAccess(document);
        return response(document);
    }

    @Transactional(readOnly = true)
    public WarehouseIssueResponse getByTrip(Long tripId) {
        WarehouseIssueDocument document = documentRepository.findByTripIdAndDeletedFalse(tripId)
                .orElseThrow(() -> new NotFoundException("Không tìm thấy phiếu xuất kho của chuyến"));
        assertCanAccess(document);
        return response(document);
    }

    @Transactional(readOnly = true)
    public List<WarehouseIssueResponse> search(WarehouseIssueStatus status) {
        List<WarehouseIssueDocument> documents = status == null
                ? documentRepository.findByDeletedFalseOrderByCreatedAtDesc()
                : documentRepository.findByDeletedFalseAndStatusOrderByCreatedAtDesc(status);
        if (SecurityUtils.hasRole("DRIVER")) {
            Long userId = SecurityUtils.currentUserId();
            documents = documents.stream()
                    .filter(item -> item.getDriver() != null
                            && item.getDriver().getUser() != null
                            && userId.equals(item.getDriver().getUser().getId()))
                    .toList();
        }
        return documents.stream().map(this::response).toList();
    }

    @Transactional
    public WarehouseIssueResponse issue(Long id) {
        WarehouseIssueDocument document = find(id);
        requireDraft(document);
        WarehouseIssueStatus previous = document.getStatus();
        document.setStatus(WarehouseIssueStatus.ISSUED);
        document.setIssuedAt(LocalDateTime.now());
        addAudit(document, "ISSUED", previous, document.getStatus(), "Phát hành phiếu xuất kho");
        return response(document);
    }

    @Transactional
    public WarehouseIssueResponse confirm(Long id, WarehouseIssueConfirmationRequest request) {
        WarehouseIssueDocument document = find(id);
        assertCanAccess(document);
        if (document.getStatus() == WarehouseIssueStatus.DRAFT
                || document.getStatus() == WarehouseIssueStatus.CANCELLED) {
            throw new BadRequestException("Phiếu chưa được phát hành hoặc đã bị hủy");
        }
        WarehouseIssueConfirmation confirmation = new WarehouseIssueConfirmation();
        confirmation.setDocument(document);
        confirmation.setRole(request.role());
        confirmation.setStatus(request.status());
        confirmation.setSignerName(request.signerName().trim());
        confirmation.setSignerPhone(trim(request.signerPhone()));
        confirmation.setLat(request.lat());
        confirmation.setLng(request.lng());
        confirmation.setEvidenceUrl(trim(request.evidenceUrl()));
        confirmation.setNote(trim(request.note()));
        confirmation.setCreatedBy(currentUser());
        if (request.status() == ConfirmationStatus.CONFIRMED) {
            confirmation.setSignedAt(LocalDateTime.now());
        }
        document.getConfirmations().add(confirmation);

        WarehouseIssueStatus previous = document.getStatus();
        if (request.status() == ConfirmationStatus.CONFIRMED && request.role() == ConfirmationRole.DRIVER) {
            document.setStatus(WarehouseIssueStatus.DRIVER_RECEIVED);
        } else if (request.status() == ConfirmationStatus.CONFIRMED
                && request.role() == ConfirmationRole.RECIPIENT) {
            document.setStatus(WarehouseIssueStatus.COMPLETED);
            document.setCompletedAt(LocalDateTime.now());
        }
        addAudit(document, "CONFIRMED_" + request.role(), previous, document.getStatus(), request.note());
        return response(document);
    }

    private void attachTrip(WarehouseIssueDocument document, Long tripId) {
        if (tripId == null) return;
        if (documentRepository.findByTripIdAndDeletedFalse(tripId).isPresent()) {
            throw new BadRequestException("Chuyến đã có phiếu xuất kho");
        }
        Trip trip = tripRepository.findById(tripId)
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Không tìm thấy chuyến đi"));
        document.setTrip(trip);
        document.setDriver(trip.getDriver());
        document.setVehicle(trip.getVehicle());
        if (trip.getDriver() != null) document.setDeliveryPersonName(trip.getDriver().getFullName());
        if (document.getDeliveryAddress() == null) document.setDeliveryAddress(trip.getEndLocation());
    }

    private void apply(WarehouseIssueDocument document, WarehouseIssueRequest request) {
        document.setIssueDate(request.issueDate());
        document.setCompanyName(trim(request.companyName()));
        document.setCompanyAddress(trim(request.companyAddress()));
        document.setIssueReason(trim(request.issueReason()));
        document.setWarehouseName(request.warehouseName().trim());
        document.setWarehouseLocation(trim(request.warehouseLocation()));
        document.setProjectName(request.projectName().trim());
        document.setWorkItem(trim(request.workItem()));
        document.setRecipientName(request.recipientName().trim());
        document.setRecipientPhone(trim(request.recipientPhone()));
        document.setDeliveryAddress(trim(request.deliveryAddress()));
        if (request.deliveryPersonName() != null && !request.deliveryPersonName().isBlank()) {
            document.setDeliveryPersonName(request.deliveryPersonName().trim());
        }
        document.setQuantityInWords(trim(request.quantityInWords()));
        document.setNotes(trim(request.notes()));
        document.replaceItems(toItems(request.items()));
    }

    private List<WarehouseIssueItem> toItems(List<WarehouseIssueItemRequest> requests) {
        return java.util.stream.IntStream.range(0, requests.size()).mapToObj(index -> {
            WarehouseIssueItemRequest request = requests.get(index);
            WarehouseIssueItem item = new WarehouseIssueItem();
            item.setLineNumber(index + 1);
            item.setItemCode(trim(request.itemCode()));
            item.setDescription(request.description().trim());
            item.setSpecification(trim(request.specification()));
            item.setUnit(request.unit().trim());
            item.setRequestedQuantity(request.requestedQuantity());
            item.setIssuedQuantity(request.issuedQuantity());
            item.setReturnedQuantity(request.returnedQuantity() == null ? BigDecimal.ZERO : request.returnedQuantity());
            item.setDeliveredQuantity(request.deliveredQuantity());
            item.setConditionNote(trim(request.conditionNote()));
            item.setConfirmationNote(trim(request.confirmationNote()));
            return item;
        }).toList();
    }

    private String resolveIssueNumber(String requested) {
        String value = requested == null || requested.isBlank() ? CodeGenerator.code("PXK") : requested.trim();
        if (documentRepository.existsByIssueNumberAndDeletedFalse(value)) {
            throw new BadRequestException("Số phiếu xuất kho đã tồn tại");
        }
        return value;
    }

    private WarehouseIssueDocument find(Long id) {
        return documentRepository.findByIdAndDeletedFalse(id)
                .orElseThrow(() -> new NotFoundException("Không tìm thấy phiếu xuất kho"));
    }

    private void requireDraft(WarehouseIssueDocument document) {
        if (document.getStatus() != WarehouseIssueStatus.DRAFT) {
            throw new BadRequestException("Chỉ phiếu nháp mới được chỉnh sửa");
        }
    }

    private void assertCanAccess(WarehouseIssueDocument document) {
        if (!SecurityUtils.hasRole("DRIVER")) return;
        if (document.getDriver() == null || document.getDriver().getUser() == null
                || !SecurityUtils.currentUserId().equals(document.getDriver().getUser().getId())) {
            throw new ForbiddenActionException("Phiếu xuất kho không thuộc chuyến của tài xế");
        }
    }

    private UserAccount currentUser() {
        return userRepository.findById(SecurityUtils.currentUserId())
                .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy tài khoản hiện tại"));
    }

    private void addAudit(WarehouseIssueDocument document, String action,
                          WarehouseIssueStatus from, WarehouseIssueStatus to, String note) {
        UserAccount actor = currentUser();
        WarehouseIssueAuditLog log = new WarehouseIssueAuditLog();
        log.setDocument(document);
        log.setAction(action);
        log.setFromStatus(from);
        log.setToStatus(to);
        log.setActor(actor);
        log.setActorName(actor.getFullName());
        log.setNote(trim(note));
        log.setCreatedAt(LocalDateTime.now());
        auditRepository.save(log);
    }

    private WarehouseIssueResponse response(WarehouseIssueDocument document) {
        List<WarehouseIssueAuditResponse> audits = document.getId() == null ? List.of()
                : auditRepository.findByDocumentIdOrderByCreatedAtAsc(document.getId()).stream()
                .map(log -> new WarehouseIssueAuditResponse(log.getId(), log.getAction(), log.getFromStatus(),
                        log.getToStatus(), log.getActorName(), log.getNote(), log.getCreatedAt()))
                .toList();
        return new WarehouseIssueResponse(
                document.getId(), id(document.getTrip()), document.getTrip() == null ? null : document.getTrip().getTripCode(),
                document.getIssueNumber(), document.getIssueDate(), document.getStatus(), document.getDocumentVersion(),
                document.getCompanyName(), document.getCompanyAddress(), document.getIssueReason(), document.getWarehouseName(),
                document.getWarehouseLocation(), document.getProjectName(), document.getWorkItem(), document.getRecipientName(),
                document.getRecipientPhone(), document.getDeliveryAddress(), document.getPreparedByName(),
                document.getDeliveryPersonName(), id(document.getDriver()),
                document.getDriver() == null ? null : document.getDriver().getFullName(), id(document.getVehicle()),
                document.getVehicle() == null ? null : document.getVehicle().getPlateNumber(), document.getQuantityInWords(),
                document.getNotes(), document.getIssuedAt(), document.getCompletedAt(), document.getCreatedAt(), document.getUpdatedAt(),
                document.getItems().stream().filter(item -> !item.isDeleted()).map(item -> new WarehouseIssueItemResponse(
                        item.getId(), item.getLineNumber(), item.getItemCode(), item.getDescription(), item.getSpecification(),
                        item.getUnit(), item.getRequestedQuantity(), item.getIssuedQuantity(), item.getReturnedQuantity(),
                        item.getDeliveredQuantity(), item.getConditionNote(), item.getConfirmationNote())).toList(),
                document.getConfirmations().stream().filter(item -> !item.isDeleted()).map(item -> new WarehouseIssueConfirmationResponse(
                        item.getId(), item.getRole(), item.getStatus(), item.getSignerName(), item.getSignerPhone(), item.getSignedAt(),
                        item.getLat(), item.getLng(), item.getEvidenceUrl(), item.getNote())).toList(), audits);
    }

    private Long id(com.safefleet.common.domain.BaseEntity entity) {
        return entity == null ? null : entity.getId();
    }

    private String trim(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
