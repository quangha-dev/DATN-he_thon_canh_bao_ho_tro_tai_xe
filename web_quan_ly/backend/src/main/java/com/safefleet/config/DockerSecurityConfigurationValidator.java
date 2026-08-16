package com.safefleet.config;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.Locale;

@Component
@Profile("docker")
public class DockerSecurityConfigurationValidator {

    private final String jwtSecret;
    private final String databasePassword;
    private final String corsAllowedOrigins;
    private final String evidenceProvider;
    private final String minioAccessKey;
    private final String minioSecretKey;

    public DockerSecurityConfigurationValidator(
            @Value("${app.jwt.secret}") String jwtSecret,
            @Value("${spring.datasource.password}") String databasePassword,
            @Value("${app.cors.allowed-origins}") String corsAllowedOrigins,
            @Value("${app.evidence.provider}") String evidenceProvider,
            @Value("${app.evidence.minio.access-key:}") String minioAccessKey,
            @Value("${app.evidence.minio.secret-key:}") String minioSecretKey) {
        this.jwtSecret = jwtSecret;
        this.databasePassword = databasePassword;
        this.corsAllowedOrigins = corsAllowedOrigins;
        this.evidenceProvider = evidenceProvider;
        this.minioAccessKey = minioAccessKey;
        this.minioSecretKey = minioSecretKey;
    }

    @PostConstruct
    void validate() {
        requireSecret("JWT_SECRET", jwtSecret, 32);
        requireSecret("POSTGRES_PASSWORD", databasePassword, 12);
        if (corsAllowedOrigins == null
                || corsAllowedOrigins.isBlank()
                || corsAllowedOrigins.contains("*")) {
            throw new IllegalStateException(
                    "CORS_ALLOWED_ORIGINS phải là danh sách origin tường minh, không dùng wildcard"
            );
        }
        if ("minio".equalsIgnoreCase(evidenceProvider)) {
            requireSecret("MINIO_ROOT_USER/MINIO_ACCESS_KEY", minioAccessKey, 3);
            requireSecret("MINIO_ROOT_PASSWORD/MINIO_SECRET_KEY", minioSecretKey, 12);
        }
    }

    private void requireSecret(String name, String value, int minimumLength) {
        String normalized = value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
        if (normalized.length() < minimumLength
                || normalized.contains("change_me")
                || normalized.contains("changeme")
                || normalized.equals("password")) {
            throw new IllegalStateException(
                    name + " chưa được cấu hình an toàn cho Docker runtime"
            );
        }
    }
}
