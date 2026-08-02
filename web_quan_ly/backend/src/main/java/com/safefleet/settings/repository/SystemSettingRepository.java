package com.safefleet.settings.repository;

import com.safefleet.settings.entity.SystemSetting;
import com.safefleet.settings.enums.SettingGroup;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SystemSettingRepository extends JpaRepository<SystemSetting, Long> {

    Optional<SystemSetting> findByKey(String key);

    List<SystemSetting> findByGroupOrderByKeyAsc(SettingGroup group);
}
