package com.safefleet.settings.mapper;

import com.safefleet.settings.dto.response.SystemSettingResponse;
import com.safefleet.settings.entity.SystemSetting;

public final class SystemSettingMapper {

    private SystemSettingMapper() {
    }

    public static SystemSettingResponse toResponse(SystemSetting setting) {
        return new SystemSettingResponse(
                setting.getId(),
                setting.getKey(),
                setting.getGroup(),
                setting.getValue(),
                setting.getValueType(),
                setting.getDescription(),
                setting.getUpdatedBy() == null ? null : setting.getUpdatedBy().getId(),
                setting.getUpdatedAt()
        );
    }
}
