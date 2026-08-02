package com.safefleet.device.service;

import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.device.dto.request.AssignDeviceVehicleRequest;
import com.safefleet.device.dto.request.CreateDeviceRequest;
import com.safefleet.device.dto.request.UpdateDeviceRequest;
import com.safefleet.device.dto.request.UpdateDeviceStatusRequest;
import com.safefleet.device.dto.response.DeviceConnectionLogResponse;
import com.safefleet.device.dto.response.DeviceResponse;
import com.safefleet.device.entity.Device;
import com.safefleet.device.entity.DeviceConnectionLog;
import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.device.enums.DeviceType;
import com.safefleet.device.mapper.DeviceMapper;
import com.safefleet.device.repository.DeviceConnectionLogRepository;
import com.safefleet.device.repository.DeviceRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.repository.VehicleRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DeviceService {

    private final DeviceRepository deviceRepository;
    private final DeviceConnectionLogRepository connectionLogRepository;
    private final VehicleRepository vehicleRepository;

    @Transactional(readOnly = true)
    public PageResponse<DeviceResponse> search(DeviceType type, DeviceStatus status, Long vehicleId, Pageable pageable) {
        Specification<Device> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isFalse(root.get("deleted")));
            if (type != null) {
                predicates.add(cb.equal(root.get("type"), type));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (vehicleId != null) {
                predicates.add(cb.equal(root.get("vehicle").get("id"), vehicleId));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.from(deviceRepository.findAll(spec, pageable).map(DeviceMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public DeviceResponse get(Long id) {
        return DeviceMapper.toResponse(findDevice(id));
    }

    @Transactional
    public DeviceResponse create(CreateDeviceRequest request) {
        if (deviceRepository.existsByDeviceCode(request.deviceCode())) {
            throw new BadRequestException("Mã thiết bị đã tồn tại");
        }
        Device device = new Device();
        device.setDeviceCode(request.deviceCode());
        apply(device, request.name(), request.type(), request.status(), request.vehicleId(),
                request.phone(), request.serialNumber(), request.firmwareVersion());
        return DeviceMapper.toResponse(deviceRepository.save(device));
    }

    @Transactional
    public DeviceResponse update(Long id, UpdateDeviceRequest request) {
        Device device = findDevice(id);
        apply(device, request.name(), request.type(), request.status(), request.vehicleId(),
                request.phone(), request.serialNumber(), request.firmwareVersion());
        return DeviceMapper.toResponse(device);
    }

    @Transactional
    public void delete(Long id) {
        Device device = findDevice(id);
        device.setDeleted(true);
    }

    @Transactional
    public DeviceResponse assignVehicle(Long id, AssignDeviceVehicleRequest request) {
        Device device = findDevice(id);
        device.setVehicle(findVehicle(request.vehicleId()));
        return DeviceMapper.toResponse(device);
    }

    @Transactional
    public DeviceResponse updateStatus(Long id, UpdateDeviceStatusRequest request) {
        Device device = findDevice(id);
        device.setStatus(request.status());
        device.setLastSeenAt(LocalDateTime.now());

        DeviceConnectionLog log = new DeviceConnectionLog();
        log.setDevice(device);
        log.setStatus(request.status());
        log.setLat(request.lat());
        log.setLng(request.lng());
        log.setNote(request.note());
        connectionLogRepository.save(log);

        return DeviceMapper.toResponse(device);
    }

    @Transactional(readOnly = true)
    public PageResponse<DeviceConnectionLogResponse> connectionLogs(Long id, Pageable pageable) {
        if (!deviceRepository.existsById(id)) {
            throw new NotFoundException("Device", id);
        }
        return PageResponse.from(connectionLogRepository.findByDeviceIdOrderByCreatedAtDesc(id, pageable)
                .map(DeviceMapper::toResponse));
    }

    private void apply(Device device,
                       String name,
                       DeviceType type,
                       DeviceStatus status,
                       Long vehicleId,
                       String phone,
                       String serialNumber,
                       String firmwareVersion) {
        device.setName(name);
        device.setType(type);
        device.setStatus(status == null ? DeviceStatus.OFFLINE : status);
        device.setVehicle(vehicleId == null ? null : findVehicle(vehicleId));
        device.setPhone(phone);
        device.setSerialNumber(serialNumber);
        device.setFirmwareVersion(firmwareVersion);
        if (device.getStatus() == DeviceStatus.ONLINE) {
            device.setLastSeenAt(LocalDateTime.now());
        }
    }

    private Device findDevice(Long id) {
        return deviceRepository.findById(id)
                .filter(device -> !device.isDeleted())
                .orElseThrow(() -> new NotFoundException("Device", id));
    }

    private Vehicle findVehicle(Long id) {
        return vehicleRepository.findById(id)
                .filter(vehicle -> !vehicle.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", id));
    }
}
