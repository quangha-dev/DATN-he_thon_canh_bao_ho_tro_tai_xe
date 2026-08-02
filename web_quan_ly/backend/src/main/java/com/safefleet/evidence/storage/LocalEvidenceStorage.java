package com.safefleet.evidence.storage;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

@Component
@ConditionalOnProperty(
        name = "app.evidence.provider",
        havingValue = "local",
        matchIfMissing = true
)
public class LocalEvidenceStorage implements EvidenceStorage {

    private final Path root;

    public LocalEvidenceStorage(
            @Value("${app.evidence.storage-path:./data/evidence}") String storagePath) {
        this.root = Path.of(storagePath).toAbsolutePath().normalize();
    }

    @Override
    public void store(String objectKey, MultipartFile file) throws IOException {
        Path target = resolve(objectKey);
        Files.createDirectories(target.getParent());
        try (var input = file.getInputStream()) {
            Files.copy(input, target);
        }
    }

    @Override
    public Resource load(String objectKey) throws IOException {
        Path target = resolve(objectKey);
        if (!Files.isRegularFile(target)) {
            throw new FileNotFoundException(objectKey);
        }
        return new FileSystemResource(target);
    }

    @Override
    public void delete(String objectKey) throws IOException {
        Files.deleteIfExists(resolve(objectKey));
    }

    private Path resolve(String objectKey) throws IOException {
        Path target = root.resolve(objectKey).normalize();
        if (!target.startsWith(root)) {
            throw new IOException("Evidence object key escapes storage root");
        }
        return target;
    }
}
