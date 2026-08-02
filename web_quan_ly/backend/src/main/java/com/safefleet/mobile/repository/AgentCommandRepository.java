package com.safefleet.mobile.repository;

import com.safefleet.mobile.entity.AgentCommand;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface AgentCommandRepository extends JpaRepository<AgentCommand, Long> {

    Page<AgentCommand> findByUserIdAndDeletedFalseOrderByCreatedAtDesc(Long userId, Pageable pageable);

    Optional<AgentCommand> findByIdAndUserIdAndDeletedFalse(Long id, Long userId);
}
