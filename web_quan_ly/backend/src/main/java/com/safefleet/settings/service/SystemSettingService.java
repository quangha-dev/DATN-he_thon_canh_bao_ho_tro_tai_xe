package com.safefleet.settings.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.settings.dto.request.UpdateSystemSettingRequest;
import com.safefleet.settings.dto.response.SystemSettingResponse;
import com.safefleet.settings.entity.SystemSetting;
import com.safefleet.settings.enums.SettingGroup;
import com.safefleet.settings.enums.SettingValueType;
import com.safefleet.settings.mapper.SystemSettingMapper;
import com.safefleet.settings.repository.SystemSettingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SystemSettingService {

    public static final String DRIVING_MAX_CONTINUOUS_MINUTES = "driving.max_continuous_minutes";
    public static final String DRIVING_WARN_1_MINUTES = "driving.warn_1_minutes";
    public static final String DRIVING_WARN_2_MINUTES = "driving.warn_2_minutes";
    public static final String DRIVING_CRITICAL_MINUTES = "driving.critical_minutes";
    public static final String FLOOD_EXPIRATION_MINUTES = "flood.expiration_minutes";

    private final SystemSettingRepository settingRepository;
    private final UserAccountRepository userAccountRepository;

    @Transactional(readOnly = true)
    public List<SystemSettingResponse> all() {
        return settingRepository.findAll().stream()
                .map(SystemSettingMapper::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<SystemSettingResponse> byGroup(SettingGroup group) {
        return settingRepository.findByGroupOrderByKeyAsc(group).stream()
                .map(SystemSettingMapper::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public SystemSettingResponse get(String key) {
        return SystemSettingMapper.toResponse(find(key));
    }

    @Transactional
    public SystemSettingResponse update(String key, UpdateSystemSettingRequest request) {
        validateValue(request.value(), request.valueType());
        SystemSetting setting = settingRepository.findByKey(key).orElseGet(() -> {
            SystemSetting created = new SystemSetting();
            created.setKey(key);
            return created;
        });
        setting.setGroup(request.group());
        setting.setValue(request.value());
        setting.setValueType(request.valueType());
        setting.setDescription(request.description());
        setting.setUpdatedBy(currentUserOrNull());
        return SystemSettingMapper.toResponse(settingRepository.save(setting));
    }

    @Transactional(readOnly = true)
    public int getInt(String key, int defaultValue) {
        return settingRepository.findByKey(key)
                .map(SystemSetting::getValue)
                .map(value -> parseInt(value, defaultValue))
                .orElse(defaultValue);
    }

    @Transactional(readOnly = true)
    public String getString(String key, String defaultValue) {
        return settingRepository.findByKey(key)
                .map(SystemSetting::getValue)
                .orElse(defaultValue);
    }

    private SystemSetting find(String key) {
        return settingRepository.findByKey(key)
                .orElseThrow(() -> new NotFoundException("Không tìm thấy cấu hình: " + key));
    }

    private void validateValue(String value, SettingValueType valueType) {
        try {
            switch (valueType) {
                case INTEGER -> Integer.parseInt(value);
                case DECIMAL -> new BigDecimal(value);
                case BOOLEAN -> {
                    if (!"true".equalsIgnoreCase(value) && !"false".equalsIgnoreCase(value)) {
                        throw new IllegalArgumentException("Invalid boolean");
                    }
                }
                case JSON -> {
                    if (!value.trim().startsWith("{") && !value.trim().startsWith("[")) {
                        throw new IllegalArgumentException("Invalid JSON-like value");
                    }
                }
                case STRING -> {
                }
            }
        } catch (RuntimeException exception) {
            throw new BadRequestException("Giá trị cấu hình không hợp lệ");
        }
    }

    private int parseInt(String value, int defaultValue) {
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException exception) {
            return defaultValue;
        }
    }

    private UserAccount currentUserOrNull() {
        try {
            return userAccountRepository.findById(SecurityUtils.currentUserId()).orElse(null);
        } catch (RuntimeException ignored) {
            return null;
        }
    }
}
