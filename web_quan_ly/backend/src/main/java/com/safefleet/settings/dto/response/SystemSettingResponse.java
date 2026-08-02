package com.safefleet.settings.dto.response;

import com.safefleet.settings.enums.SettingGroup;
import com.safefleet.settings.enums.SettingValueType;

import java.time.LocalDateTime;

public record SystemSettingResponse(
        Long id,
        String key,
        SettingGroup group,
        String value,
        SettingValueType valueType,
        String description,
        Long updatedBy,
        LocalDateTime updatedAt
) {
}
