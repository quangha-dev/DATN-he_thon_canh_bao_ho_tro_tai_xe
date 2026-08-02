package com.safefleet.auth.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.auth.dto.request.LoginRequest;
import com.safefleet.auth.dto.request.RefreshTokenRequest;
import com.safefleet.auth.dto.response.AuthResponse;
import com.safefleet.auth.dto.response.CurrentUserResponse;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.common.exception.UnauthorizedException;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.infrastructure.security.JwtService;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.infrastructure.security.UserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final UserAccountRepository userAccountRepository;
    private final DriverRepository driverRepository;
    private final JdbcTemplate jdbcTemplate;

    @Value("${app.jwt.refresh-expiration-days:30}")
    private long refreshExpirationDays;

    @Transactional
    public AuthResponse login(LoginRequest request) {
        var authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.usernameOrEmail(), request.password())
        );
        UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();
        UserAccount user = userAccountRepository.findById(principal.getId())
                .orElseThrow(() -> new NotFoundException("User", principal.getId()));
        return issueTokenPair(user);
    }

    @Transactional
    public AuthResponse refresh(RefreshTokenRequest request) {
        String tokenHash = hashToken(request.refreshToken());
        Long userId;
        try {
            userId = jdbcTemplate.queryForObject("""
                    SELECT user_id
                    FROM refresh_tokens
                    WHERE token_hash = ?
                      AND revoked_at IS NULL
                      AND expires_at > CURRENT_TIMESTAMP(6)
                    FOR UPDATE
                    """, Long.class, tokenHash);
        } catch (EmptyResultDataAccessException exception) {
            throw new UnauthorizedException("Refresh token không hợp lệ hoặc đã hết hạn");
        }

        jdbcTemplate.update("""
                UPDATE refresh_tokens
                SET revoked_at = CURRENT_TIMESTAMP(6), last_used_at = CURRENT_TIMESTAMP(6)
                WHERE token_hash = ?
                """, tokenHash);
        UserAccount user = userAccountRepository.findById(userId)
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new UnauthorizedException("Tài khoản không còn khả dụng"));
        UserPrincipal principal = UserPrincipal.from(user);
        if (!principal.isEnabled() || !principal.isAccountNonLocked()) {
            throw new UnauthorizedException("Tài khoản không còn khả dụng");
        }
        return issueTokenPair(user);
    }

    @Transactional
    public void logout(RefreshTokenRequest request) {
        jdbcTemplate.update("""
                UPDATE refresh_tokens
                SET revoked_at = COALESCE(revoked_at, CURRENT_TIMESTAMP(6)),
                    last_used_at = CURRENT_TIMESTAMP(6)
                WHERE token_hash = ?
                """, hashToken(request.refreshToken()));
    }

    @Transactional(readOnly = true)
    public CurrentUserResponse currentUser() {
        Long userId = SecurityUtils.currentUserId();
        UserAccount user = userAccountRepository.findById(userId)
                .orElseThrow(() -> new NotFoundException("User", userId));
        Long driverId = driverRepository.findByUserId(userId).map(driver -> driver.getId()).orElse(null);
        return new CurrentUserResponse(
                user.getId(),
                driverId,
                user.getUsername(),
                user.getEmail(),
                user.getFullName(),
                user.getStatus(),
                user.getRole().getName()
        );
    }

    private AuthResponse issueTokenPair(UserAccount user) {
        UserPrincipal principal = UserPrincipal.from(user);
        String refreshToken = generateRefreshToken();
        jdbcTemplate.update("""
                INSERT INTO refresh_tokens (user_id, token_hash, expires_at, created_at)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP(6))
                """, user.getId(), hashToken(refreshToken), LocalDateTime.now().plusDays(refreshExpirationDays));
        Long driverId = driverRepository.findByUserId(user.getId()).map(driver -> driver.getId()).orElse(null);
        return new AuthResponse(
                jwtService.generateToken(principal),
                refreshToken,
                "Bearer",
                jwtService.expirationSeconds(),
                user.getId(),
                driverId,
                user.getUsername(),
                user.getEmail(),
                user.getFullName(),
                user.getRole().getName()
        );
    }

    private String generateRefreshToken() {
        byte[] tokenBytes = new byte[48];
        SECURE_RANDOM.nextBytes(tokenBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(tokenBytes);
    }

    private String hashToken(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is not available", exception);
        }
    }
}
