package com.safefleet.config;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DockerSecurityConfigurationValidatorTest {

    @Test
    void acceptsExplicitStrongDockerConfiguration() {
        var validator = new DockerSecurityConfigurationValidator(
                "jwt-secret-with-at-least-thirty-two-characters",
                "database-password-strong",
                "https://fleet.example.vn",
                "minio",
                "safefleet-minio",
                "minio-password-strong"
        );

        assertThatCode(validator::validate).doesNotThrowAnyException();
    }

    @Test
    void rejectsPlaceholdersAndWildcardCors() {
        var placeholder = new DockerSecurityConfigurationValidator(
                "change_me_to_at_least_32_random_characters",
                "change_me_app_password",
                "https://fleet.example.vn",
                "local",
                "",
                ""
        );
        var wildcardCors = new DockerSecurityConfigurationValidator(
                "jwt-secret-with-at-least-thirty-two-characters",
                "database-password-strong",
                "*",
                "local",
                "",
                ""
        );

        assertThatThrownBy(placeholder::validate)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET");
        assertThatThrownBy(wildcardCors::validate)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("CORS_ALLOWED_ORIGINS");
    }

    @Test
    void requiresMinioCredentialsOnlyWhenMinioIsSelected() {
        var minio = new DockerSecurityConfigurationValidator(
                "jwt-secret-with-at-least-thirty-two-characters",
                "database-password-strong",
                "https://fleet.example.vn",
                "minio",
                "",
                ""
        );
        var local = new DockerSecurityConfigurationValidator(
                "jwt-secret-with-at-least-thirty-two-characters",
                "database-password-strong",
                "https://fleet.example.vn",
                "local",
                "",
                ""
        );

        assertThatThrownBy(minio::validate)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("MINIO_ROOT_USER");
        assertThatCode(local::validate).doesNotThrowAnyException();
    }
}
