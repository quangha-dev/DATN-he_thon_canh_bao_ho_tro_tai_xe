package com.safefleet.common.exception;

import org.springframework.http.HttpStatus;

public class NotFoundException extends BusinessException {

    public NotFoundException(String resource, Object id) {
        super(HttpStatus.NOT_FOUND, "Không tìm thấy " + displayName(resource) + ": " + id);
    }

    public NotFoundException(String message) {
        super(HttpStatus.NOT_FOUND, message);
    }

    private static String displayName(String resource) {
        return switch (resource) {
            case "User" -> "tài khoản";
            case "Role" -> "vai trò";
            case "Vehicle" -> "phương tiện";
            case "Driver" -> "tài xế";
            case "Device" -> "thiết bị";
            case "Trip" -> "chuyến đi";
            case "Safety event" -> "cảnh báo an toàn";
            case "Incident" -> "sự cố";
            case "Flood report" -> "điểm ngập";
            case "Maintenance order" -> "phiếu bảo trì";
            case "Notification" -> "thông báo";
            case "Driving session" -> "phiên lái";
            default -> resource;
        };
    }
}
