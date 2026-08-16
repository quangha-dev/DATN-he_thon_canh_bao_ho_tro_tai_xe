package com.safefleet.account.service;

import com.safefleet.account.dto.request.CreateDriverAccountRequest;
import com.safefleet.account.dto.request.CreateUserRequest;
import com.safefleet.account.dto.request.ResetPasswordRequest;
import com.safefleet.account.dto.request.UpdateAccountStatusRequest;
import com.safefleet.account.dto.response.UserResponse;
import com.safefleet.account.entity.Role;
import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.enums.AccountStatus;
import com.safefleet.account.enums.RoleName;
import com.safefleet.account.mapper.UserMapper;
import com.safefleet.account.repository.RoleRepository;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.infrastructure.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AccountService {

    private final UserAccountRepository userAccountRepository;
    private final RoleRepository roleRepository;
    private final DriverRepository driverRepository;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbcTemplate;

    @Transactional(readOnly = true)
    public PageResponse<UserResponse> search(String keyword, Pageable pageable) {
        String normalizedKeyword = keyword == null ? null : keyword.trim();
        var users = normalizedKeyword == null || normalizedKeyword.isEmpty()
                ? userAccountRepository.findByDeletedFalse(pageable)
                : userAccountRepository.searchByKeyword(normalizedKeyword, pageable);
        return PageResponse.from(users.map(UserMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public UserResponse get(Long id) {
        return UserMapper.toResponse(findUser(id));
    }

    @Transactional
    public UserResponse create(CreateUserRequest request) {
        if (!SecurityUtils.hasRole("ADMIN")
                && request.role() != RoleName.FLEET_MANAGER
                && request.role() != RoleName.DRIVER) {
            throw new ForbiddenActionException("Quản lý chỉ được tạo tài khoản quản lý hoặc tài xế");
        }
        validateUniqueUser(request.username(), request.email());
        Role role = roleRepository.findByName(request.role())
                .orElseThrow(() -> new NotFoundException("Không tìm thấy vai trò: " + request.role()));

        UserAccount user = new UserAccount();
        user.setUsername(request.username());
        user.setEmail(request.email());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setFullName(request.fullName());
        user.setPhone(request.phone());
        user.setStatus(AccountStatus.ACTIVE);
        user.setRole(role);
        return UserMapper.toResponse(userAccountRepository.save(user));
    }

    @Transactional
    public UserResponse createDriverAccount(CreateDriverAccountRequest request) {
        validateUniqueUser(request.username(), request.email());
        if (driverRepository.existsByLicenseNumber(request.licenseNumber())) {
            throw new BadRequestException("Số giấy phép đã tồn tại");
        }

        Role role = roleRepository.findByName(RoleName.DRIVER)
                .orElseThrow(() -> new NotFoundException("Không tìm thấy vai trò DRIVER"));
        UserAccount user = new UserAccount();
        user.setUsername(request.username());
        user.setEmail(request.email());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setFullName(request.fullName());
        user.setPhone(request.phone());
        user.setStatus(AccountStatus.ACTIVE);
        user.setRole(role);
        UserAccount savedUser = userAccountRepository.save(user);

        Driver driver = new Driver();
        driver.setUser(savedUser);
        driver.setFullName(request.fullName());
        driver.setPhone(request.phone());
        driver.setEmail(request.email());
        driver.setAddress(request.address());
        driver.setLicenseNumber(request.licenseNumber());
        driver.setLicenseClass(request.licenseClass());
        driver.setLicenseExpiredAt(request.licenseExpiredAt());
        driver.setStatus(DriverStatus.AVAILABLE);
        driverRepository.save(driver);

        return UserMapper.toResponse(savedUser);
    }

    @Transactional
    public UserResponse updateStatus(Long id, UpdateAccountStatusRequest request) {
        UserAccount user = findUser(id);
        assertManageable(user);
        if (id.equals(SecurityUtils.currentUserId()) && request.status() != AccountStatus.ACTIVE) {
            throw new BadRequestException("Không thể tự khóa hoặc vô hiệu hóa tài khoản đang đăng nhập");
        }
        user.setStatus(request.status());
        if (request.status() != AccountStatus.ACTIVE) {
            revokeAllSessions(id);
        }
        return UserMapper.toResponse(user);
    }

    @Transactional
    public void resetPassword(Long id, ResetPasswordRequest request) {
        UserAccount user = findUser(id);
        assertManageable(user);
        if (passwordEncoder.matches(request.newPassword(), user.getPasswordHash())) {
            throw new BadRequestException("Mật khẩu mới phải khác mật khẩu hiện tại");
        }
        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        revokeAllSessions(id);
    }

    private void revokeAllSessions(Long userId) {
        jdbcTemplate.update("""
                UPDATE refresh_tokens
                SET revoked_at = COALESCE(revoked_at, CURRENT_TIMESTAMP),
                    last_used_at = CURRENT_TIMESTAMP
                WHERE user_id = ? AND revoked_at IS NULL
                """, userId);
    }

    private void assertManageable(UserAccount user) {
        if (!SecurityUtils.hasRole("ADMIN") && user.getRole().getName() == RoleName.ADMIN) {
            throw new ForbiddenActionException("Quản lý không được thay đổi tài khoản quản trị hệ thống");
        }
    }

    private UserAccount findUser(Long id) {
        return userAccountRepository.findById(id)
                .filter(user -> !user.isDeleted())
                .orElseThrow(() -> new NotFoundException("User", id));
    }

    private void validateUniqueUser(String username, String email) {
        if (userAccountRepository.existsByUsername(username)) {
            throw new BadRequestException("Tên đăng nhập đã tồn tại");
        }
        if (userAccountRepository.existsByEmail(email)) {
            throw new BadRequestException("Email đã tồn tại");
        }
    }
}
