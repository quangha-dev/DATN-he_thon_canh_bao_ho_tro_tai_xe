package com.safefleet.settings.dto.request;

import com.safefleet.settings.enums.SettingGroup;
import com.safefleet.settings.enums.SettingValueType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpdateSystemSettingRequest(
        @NotNull SettingGroup group,
        @NotBlank String value,
        @NotNull SettingValueType valueType,
        @Size(max = 255) String description
) {
}
