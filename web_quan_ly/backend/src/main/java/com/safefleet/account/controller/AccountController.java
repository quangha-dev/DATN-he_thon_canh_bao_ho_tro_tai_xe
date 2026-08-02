package com.safefleet.account.controller;

import com.safefleet.account.dto.request.CreateDriverAccountRequest;
import com.safefleet.account.dto.request.CreateUserRequest;
import com.safefleet.account.dto.request.UpdateAccountStatusRequest;
import com.safefleet.account.dto.response.UserResponse;
import com.safefleet.account.service.AccountService;
import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Accounts", description = "Account and RBAC management APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/accounts")
public class AccountController {

    private final AccountService accountService;

    @Operation(summary = "Search accounts")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<PageResponse<UserResponse>> search(@RequestParam(required = false) String keyword,
                                                          Pageable pageable) {
        return ApiResponse.ok(accountService.search(keyword, pageable));
    }

    @Operation(summary = "Get account detail")
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<UserResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(accountService.get(id));
    }

    @Operation(summary = "Create staff account")
    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<UserResponse> create(@Valid @RequestBody CreateUserRequest request) {
        return ApiResponse.ok("Account created", accountService.create(request));
    }

    @Operation(summary = "Create driver account and driver profile")
    @PostMapping("/drivers")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<UserResponse> createDriver(@Valid @RequestBody CreateDriverAccountRequest request) {
        return ApiResponse.ok("Driver account created", accountService.createDriverAccount(request));
    }

    @Operation(summary = "Change account status")
    @PatchMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<UserResponse> updateStatus(@PathVariable Long id,
                                                  @Valid @RequestBody UpdateAccountStatusRequest request) {
        return ApiResponse.ok("Account status updated", accountService.updateStatus(id, request));
    }
}
