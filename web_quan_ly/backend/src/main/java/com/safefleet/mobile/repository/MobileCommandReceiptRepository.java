package com.safefleet.mobile.repository;

import com.safefleet.mobile.entity.MobileCommandReceipt;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MobileCommandReceiptRepository extends JpaRepository<MobileCommandReceipt, Long> {

    Optional<MobileCommandReceipt> findByUserIdAndClientEventIdAndDeletedFalse(
            Long userId,
            String clientEventId
    );
}
