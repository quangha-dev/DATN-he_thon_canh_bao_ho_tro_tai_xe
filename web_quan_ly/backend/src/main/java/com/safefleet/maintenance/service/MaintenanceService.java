package com.safefleet.maintenance.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.common.util.CodeGenerator;
import com.safefleet.maintenance.dto.request.CreateMaintenanceOrderRequest;
import com.safefleet.maintenance.dto.request.UpdateMaintenanceOrderRequest;
import com.safefleet.maintenance.dto.response.DocumentExpiryAlertResponse;
import com.safefleet.maintenance.dto.response.MaintenanceOrderResponse;
import com.safefleet.maintenance.entity.MaintenanceOrder;
import com.safefleet.maintenance.enums.MaintenancePriority;
import com.safefleet.maintenance.enums.MaintenanceStatus;
import com.safefleet.maintenance.mapper.MaintenanceMapper;
import com.safefleet.maintenance.repository.MaintenanceOrderRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.repository.VehicleRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MaintenanceService {

    private final MaintenanceOrderRepository maintenanceOrderRepository;
    private final VehicleRepository vehicleRepository;
    private final UserAccountRepository userAccountRepository;

    @Transactional(readOnly = true)
    public PageResponse<MaintenanceOrderResponse> search(Long vehicleId,
                                                         MaintenanceStatus status,
                                                         LocalDate from,
                                                         LocalDate to,
                                                         Pageable pageable) {
        Specification<MaintenanceOrder> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isFalse(root.get("deleted")));
            if (vehicleId != null) {
                predicates.add(cb.equal(root.get("vehicle").get("id"), vehicleId));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (from != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("scheduledDate"), from));
            }
            if (to != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("scheduledDate"), to));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.from(maintenanceOrderRepository.findAll(spec, pageable).map(MaintenanceMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public MaintenanceOrderResponse get(Long id) {
        return MaintenanceMapper.toResponse(findOrder(id));
    }

    @Transactional
    public MaintenanceOrderResponse create(CreateMaintenanceOrderRequest request) {
        MaintenanceOrder order = new MaintenanceOrder();
        order.setMaintenanceCode(CodeGenerator.code("MTN"));
        apply(order, request.vehicleId(), request.type(), request.title(), request.description(), request.scheduledDate(),
                request.completedDate(), request.cost(), request.status() == null ? MaintenanceStatus.OPEN : request.status(),
                request.priority() == null ? MaintenancePriority.MEDIUM : request.priority(), request.assignedTo(), request.note());
        return MaintenanceMapper.toResponse(maintenanceOrderRepository.save(order));
    }

    @Transactional
    public MaintenanceOrderResponse update(Long id, UpdateMaintenanceOrderRequest request) {
        MaintenanceOrder order = findOrder(id);
        apply(order, request.vehicleId(), request.type(), request.title(), request.description(), request.scheduledDate(),
                request.completedDate(), request.cost(), request.status(), request.priority(), request.assignedTo(), request.note());
        return MaintenanceMapper.toResponse(order);
    }

    @Transactional
    public void delete(Long id) {
        findOrder(id).setDeleted(true);
    }

    @Transactional(readOnly = true)
    public List<MaintenanceOrderResponse> dueAlerts() {
        return maintenanceOrderRepository.findByDeletedFalseAndStatusInAndScheduledDateBetween(
                List.of(MaintenanceStatus.OPEN, MaintenanceStatus.SCHEDULED, MaintenanceStatus.IN_PROGRESS),
                LocalDate.now(),
                LocalDate.now().plusDays(7)
        ).stream().map(MaintenanceMapper::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<DocumentExpiryAlertResponse> documentExpiryAlerts() {
        List<Vehicle> vehicles = vehicleRepository.findAll((root, query, cb) -> cb.isFalse(root.get("deleted")));
        List<DocumentExpiryAlertResponse> alerts = new ArrayList<>();
        LocalDate now = LocalDate.now();
        for (Vehicle vehicle : vehicles) {
            addExpiryAlert(alerts, vehicle, "INSPECTION", vehicle.getInspectionExpiredAt(), now);
            addExpiryAlert(alerts, vehicle, "INSURANCE", vehicle.getInsuranceExpiredAt(), now);
        }
        return alerts;
    }

    private void addExpiryAlert(List<DocumentExpiryAlertResponse> alerts, Vehicle vehicle, String type, LocalDate expiredAt, LocalDate now) {
        if (expiredAt == null) {
            return;
        }
        long days = ChronoUnit.DAYS.between(now, expiredAt);
        if (days <= 30) {
            alerts.add(new DocumentExpiryAlertResponse(vehicle.getId(), vehicle.getPlateNumber(), type, expiredAt, days));
        }
    }

    private void apply(MaintenanceOrder order,
                       Long vehicleId,
                       com.safefleet.maintenance.enums.MaintenanceType type,
                       String title,
                       String description,
                       LocalDate scheduledDate,
                       LocalDate completedDate,
                       java.math.BigDecimal cost,
                       MaintenanceStatus status,
                       MaintenancePriority priority,
                       Long assignedTo,
                       String note) {
        order.setVehicle(findVehicle(vehicleId));
        order.setType(type);
        order.setTitle(title);
        order.setDescription(description);
        order.setScheduledDate(scheduledDate);
        order.setCompletedDate(completedDate);
        order.setCost(cost);
        order.setStatus(status);
        order.setPriority(priority);
        order.setAssignedTo(assignedTo == null ? null : findUser(assignedTo));
        order.setNote(note);
    }

    private MaintenanceOrder findOrder(Long id) {
        return maintenanceOrderRepository.findById(id)
                .filter(order -> !order.isDeleted())
                .orElseThrow(() -> new NotFoundException("Maintenance order", id));
    }

    private Vehicle findVehicle(Long id) {
        return vehicleRepository.findById(id)
                .filter(vehicle -> !vehicle.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", id));
    }

    private UserAccount findUser(Long id) {
        return userAccountRepository.findById(id)
                .filter(user -> !user.isDeleted())
                .orElseThrow(() -> new NotFoundException("User", id));
    }
}
