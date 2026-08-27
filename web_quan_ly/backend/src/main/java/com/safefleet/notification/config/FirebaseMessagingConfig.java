package com.safefleet.notification.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

@Configuration
@ConditionalOnProperty(name = "app.push.fcm-enabled", havingValue = "true")
public class FirebaseMessagingConfig {

    @Bean
    FirebaseMessaging firebaseMessaging(
            @Value("${app.push.credentials-path:}") String credentialsPath
    ) throws IOException {
        GoogleCredentials credentials;
        if (credentialsPath == null || credentialsPath.isBlank()) {
            // Production nên cấp Application Default Credentials qua workload
            // identity. Không bao giờ đưa JSON service-account vào repository.
            credentials = GoogleCredentials.getApplicationDefault();
        } else {
            Path path = Path.of(credentialsPath).toAbsolutePath().normalize();
            if (!Files.isRegularFile(path)) {
                throw new IllegalStateException("FCM credentials file does not exist: " + path);
            }
            try (InputStream input = Files.newInputStream(path)) {
                credentials = GoogleCredentials.fromStream(input);
            }
        }

        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(credentials)
                .build();
        FirebaseApp app = FirebaseApp.getApps().stream()
                .filter(item -> FirebaseApp.DEFAULT_APP_NAME.equals(item.getName()))
                .findFirst()
                .orElseGet(() -> FirebaseApp.initializeApp(options));
        return FirebaseMessaging.getInstance(app);
    }
}
