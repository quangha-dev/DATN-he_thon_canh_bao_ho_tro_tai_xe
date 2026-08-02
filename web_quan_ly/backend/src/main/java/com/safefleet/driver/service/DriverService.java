package com.safefleet.driver.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.driver.dto.request.CreateDriverRequest;
import com.safefleet.driver.dto.request.UpdateDriverRequest;
import com.safefleet.driver.dto.response.DriverResponse;
import com.safefleet.driver.dto.response.DrivingTimeTodayResponse;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.driver.mapper.DriverMapper;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.repository.VehicleRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DriverService {

    private final DriverRepository driverRepository;
    private final VehicleRepository vehicleRepository;
    private final UserAccountRepository userAccountRepository;

    @Transactional(readOnly = true)
    public PageResponse<DriverResponse> search(String keyword,
                                               DriverStatus status,
                                               String licenseClass,
                                               Integer minSafetyScore,
                                               Integer maxSafetyScore,
                                               Pageable pageable) {
        Specification<Driver> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isFalse(root.get("deleted")));
            if (keyword != null && !keyword.isBlank()) {
                String pattern = "%" + keyword.toLowerCase() + "%";
                predicates.add(cb.or(
                        cb.like(cb.lower(root.get("fullName")), pattern),
                        cb.like(cb.lower(root.get("phone")), pattern),
                        cb.like(cb.lower(root.get("email")), pattern)
                ));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (licenseClass != null && !licenseClass.isBlank()) {
                predicates.add(cb.equal(cb.lower(root.get("licenseClass")), licenseClass.toLowerCase()));
            }
            if (minSafetyScore != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("safetyScore"), minSafetyScore));
            }
            if (maxSafetyScore != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("safetyScore"), maxSafetyScore));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.from(driverRepository.findAll(spec, pageable).map(DriverMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public DriverResponse get(Long id) {
        Driver driver = findDriver(id);
        assertDriverCanAccess(driver);
        return DriverMapper.toResponse(driver);
    }

    @Transactional
    public DriverResponse create(CreateDriverRequest request) {
        if (driverRepository.existsByLicenseNumber(request.licenseNumber())) {
            throw new BadRequestException("Số giấy phép đã tồn tại");
        }
        Driver driver = new Driver();
        driver.setLicenseNumber(request.licenseNumber());
        apply(driver, request.userId(), request.fullName(), request.phone(), request.email(),
                request.address(), request.licenseClass(), request.licenseExpiredAt(),
                request.status() == null ? DriverStatus.AVAILABLE : request.status(),
                request.currentVehicleId());
        return DriverMapper.toResponse(driverRepository.save(driver));
    }

    @Transactional
    public DriverResponse update(Long id, UpdateDriverRequest request) {
        Driver driver = findDriver(id);
        apply(driver, driver.getUser() == null ? null : driver.getUser().getId(), request.fullName(),
                request.phone(), request.email(), request.address(), request.licenseClass(),
                request.licenseExpiredAt(), request.status(), request.currentVehicleId());
        return DriverMapper.toResponse(driver);
    }

    @Transactional
    public void delete(Long id) {
        Driver driver = findDriver(id);
        driver.setDeleted(true);
    }

    @Transactional(readOnly = true)
    public DrivingTimeTodayResponse drivingTimeToday(Long id) {
        Driver driver = findDriver(id);
        assertDriverCanAccess(driver);
        return DriverMapper.toDrivingTime(driver);
    }

    @Transactional
    public DriverResponse recalculateSafetyScore(Long id) {
        Driver driver = findDriver(id);
        int score = Math.max(0, 100 - driver.getTotalAlerts() * 3);
        driver.setSafetyScore(score);
        if (score < 50 && driver.getStatus() != DriverStatus.SUSPENDED) {
            driver.setStatus(DriverStatus.HIGH_RISK);
        }
        return DriverMapper.toResponse(driver);
    }

    public Driver findDriver(Long id) {
        return driverRepository.findById(id)
                .filter(driver -> !driver.isDeleted())
                .orElseThrow(() -> new NotFoundException("Driver", id));
    }

    private void apply(Driver driver,
                       Long userId,
                       String fullName,
                       String phone,
                       String email,
                       String address,
                       String licenseClass,
                       java.time.LocalDate licenseExpiredAt,
                       DriverStatus status,
                       Long currentVehicleId) {
        driver.setUser(userId == null ? null : findUser(userId));
        driver.setFullName(fullName);
        driver.setPhone(phone);
        driver.setEmail(email);
        driver.setAddress(address);
        driver.setLicenseClass(licenseClass);
        driver.setLicenseExpiredAt(licenseExpiredAt);
        driver.setStatus(status);
        driver.setCurrentVehicle(currentVehicleId == null ? null : findVehicle(currentVehicleId));
    }

    private UserAccount findUser(Long id) {
        return userAccountRepository.findById(id)
                .filter(user -> !user.isDeleted())
                .orElseThrow(() -> new NotFoundException("User", id));
    }

    private Vehicle findVehicle(Long id) {
        return vehicleRepository.findById(id)
                .filter(vehicle -> !vehicle.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", id));
    }

    private void assertDriverCanAccess(Driver driver) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return;
        }
        if (driver.getUser() == null || !driver.getUser().getId().equals(SecurityUtils.currentUserId())) {
            throw new com.safefleet.common.exception.ForbiddenActionException("Tài xế chỉ được xem dữ liệu của chính mình");
        }
    }
}
