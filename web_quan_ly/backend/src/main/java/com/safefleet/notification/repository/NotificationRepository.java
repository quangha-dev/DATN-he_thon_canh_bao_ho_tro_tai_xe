package com.safefleet.notification.repository;

import com.safefleet.notification.entity.Notification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    @Query("""
            select n from Notification n
            where n.recipient is null or n.recipient.id = :userId
            order by n.createdAt desc
            """)
    Page<Notification> findVisibleToUser(@Param("userId") Long userId, Pageable pageable);

    @Query("""
            select n from Notification n
            where n.id = :id and (n.recipient is null or n.recipient.id = :userId)
            """)
    Optional<Notification> findVisibleById(@Param("id") Long id, @Param("userId") Long userId);

    long countByRecipientIdAndReadAtIsNull(Long recipientId);
}
