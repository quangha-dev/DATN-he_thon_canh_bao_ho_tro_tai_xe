package com.safefleet.maintenance.repository;

import com.safefleet.maintenance.entity.MaintenanceOrder;
import com.safefleet.maintenance.enums.MaintenanceStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;

public interface MaintenanceOrderRepository extends JpaRepository<MaintenanceOrder, Long>, JpaSpecificationExecutor<MaintenanceOrder> {

    List<MaintenanceOrder> findByDeletedFalseAndStatusInAndScheduledDateBetween(Collection<MaintenanceStatus> statuses, LocalDate from, LocalDate to);
}
