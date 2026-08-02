package com.safefleet.vehicle.service;

import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.device.entity.Device;
import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.device.repository.DeviceRepository;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.vehicle.dto.request.CreateVehicleRequest;
import com.safefleet.vehicle.dto.request.UpdateVehicleRequest;
import com.safefleet.vehicle.dto.response.VehicleRealtimeStatusResponse;
import com.safefleet.vehicle.dto.response.VehicleResponse;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.enums.VehicleType;
import com.safefleet.vehicle.mapper.VehicleMapper;
import com.safefleet.vehicle.repository.VehicleRepository;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;
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
public class VehicleService {

    private final VehicleRepository vehicleRepository;
    private final DriverRepository driverRepository;
    private final DeviceRepository deviceRepository;

    @Transactional(readOnly = true)
    public PageResponse<VehicleResponse> search(String plateNumber,
                                                VehicleType vehicleType,
                                                VehicleStatus status,
                                                Boolean gpsOnline,
                                                Pageable pageable) {
        Specification<Vehicle> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isFalse(root.get("deleted")));
            if (plateNumber != null && !plateNumber.isBlank()) {
                predicates.add(cb.like(cb.lower(root.get("plateNumber")), "%" + plateNumber.toLowerCase() + "%"));
            }
            if (vehicleType != null) {
                predicates.add(cb.equal(root.get("vehicleType"), vehicleType));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (gpsOnline != null) {
                Join<Vehicle, Device> gps = root.join("gpsDevice", JoinType.LEFT);
                predicates.add(gpsOnline
                        ? cb.equal(gps.get("status"), DeviceStatus.ONLINE)
                        : cb.or(cb.isNull(gps.get("id")), cb.notEqual(gps.get("status"), DeviceStatus.ONLINE)));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.from(vehicleRepository.findAll(spec, pageable).map(VehicleMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public VehicleResponse get(Long id) {
        return VehicleMapper.toResponse(findVehicle(id));
    }

    @Transactional
    public VehicleResponse create(CreateVehicleRequest request) {
        if (vehicleRepository.existsByPlateNumber(request.plateNumber())) {
            throw new BadRequestException("Biển số đã tồn tại");
        }
        Vehicle vehicle = new Vehicle();
        vehicle.setPlateNumber(request.plateNumber());
        apply(vehicle, request.vehicleType(), request.brand(), request.model(), request.year(),
                request.loadCapacity(), request.seatCount(), request.fuelType(),
                request.status() == null ? VehicleStatus.AVAILABLE : request.status(),
                request.currentDriverId(), request.gpsDeviceId(), request.cameraDeviceId(),
                request.inspectionExpiredAt(), request.insuranceExpiredAt());
        return VehicleMapper.toResponse(vehicleRepository.save(vehicle));
    }

    @Transactional
    public VehicleResponse update(Long id, UpdateVehicleRequest request) {
        Vehicle vehicle = findVehicle(id);
        apply(vehicle, request.vehicleType(), request.brand(), request.model(), request.year(),
                request.loadCapacity(), request.seatCount(), request.fuelType(), request.status(),
                request.currentDriverId(), request.gpsDeviceId(), request.cameraDeviceId(),
                request.inspectionExpiredAt(), request.insuranceExpiredAt());
        return VehicleMapper.toResponse(vehicle);
    }

    @Transactional
    public void delete(Long id) {
        Vehicle vehicle = findVehicle(id);
        vehicle.setDeleted(true);
    }

    @Transactional(readOnly = true)
    public VehicleRealtimeStatusResponse realtimeStatus(Long id) {
        return VehicleMapper.toRealtimeStatus(findVehicle(id));
    }

    @Transactional(readOnly = true)
    public List<VehicleRealtimeStatusResponse> currentPositions() {
        return vehicleRepository.findAll((root, query, cb) -> cb.isFalse(root.get("deleted"))).stream()
                .map(VehicleMapper::toRealtimeStatus)
                .toList();
    }

    public Vehicle findVehicle(Long id) {
        return vehicleRepository.findById(id)
                .filter(vehicle -> !vehicle.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", id));
    }

    private void apply(Vehicle vehicle,
                       VehicleType vehicleType,
                       String brand,
                       String model,
                       Integer year,
                       java.math.BigDecimal loadCapacity,
                       Integer seatCount,
                       com.safefleet.vehicle.enums.FuelType fuelType,
                       VehicleStatus status,
                       Long currentDriverId,
                       Long gpsDeviceId,
                       Long cameraDeviceId,
                       java.time.LocalDate inspectionExpiredAt,
                       java.time.LocalDate insuranceExpiredAt) {
        vehicle.setVehicleType(vehicleType);
        vehicle.setBrand(brand);
        vehicle.setModel(model);
        vehicle.setYear(year);
        vehicle.setLoadCapacity(loadCapacity);
        vehicle.setSeatCount(seatCount);
        vehicle.setFuelType(fuelType);
        vehicle.setStatus(status);
        vehicle.setCurrentDriver(currentDriverId == null ? null : findDriver(currentDriverId));
        vehicle.setGpsDevice(gpsDeviceId == null ? null : findDevice(gpsDeviceId));
        vehicle.setCameraDevice(cameraDeviceId == null ? null : findDevice(cameraDeviceId));
        vehicle.setInspectionExpiredAt(inspectionExpiredAt);
        vehicle.setInsuranceExpiredAt(insuranceExpiredAt);
    }

    private Driver findDriver(Long id) {
        return driverRepository.findById(id)
                .filter(driver -> !driver.isDeleted())
                .orElseThrow(() -> new NotFoundException("Driver", id));
    }

    private Device findDevice(Long id) {
        return deviceRepository.findById(id)
                .filter(device -> !device.isDeleted())
                .orElseThrow(() -> new NotFoundException("Device", id));
    }
}
