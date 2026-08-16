package com.safefleet.account.repository;

import com.safefleet.account.entity.UserAccount;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface UserAccountRepository extends JpaRepository<UserAccount, Long> {

    Optional<UserAccount> findByUsername(String username);

    Optional<UserAccount> findByEmail(String email);

    @Query("""
            select u from UserAccount u
            join fetch u.role
            where lower(u.username) = lower(:value) or lower(u.email) = lower(:value)
            """)
    Optional<UserAccount> findForLogin(@Param("value") String value);

    boolean existsByUsername(String username);

    boolean existsByEmail(String email);

    Page<UserAccount> findByDeletedFalse(Pageable pageable);

    @Query("""
            select u from UserAccount u
            where u.deleted = false
              and (lower(u.username) like lower(concat('%', :keyword, '%'))
                   or lower(u.email) like lower(concat('%', :keyword, '%'))
                   or lower(u.fullName) like lower(concat('%', :keyword, '%')))
            """)
    Page<UserAccount> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);
}
