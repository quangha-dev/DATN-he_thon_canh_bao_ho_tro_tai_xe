package com.safefleet.evidence.storage;

import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import io.minio.errors.ErrorResponseException;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.FileNotFoundException;
import java.io.IOException;

@Component
@ConditionalOnProperty(name = "app.evidence.provider", havingValue = "minio")
public class MinioEvidenceStorage implements EvidenceStorage {

    private final MinioClient client;
    private final String bucket;

    public MinioEvidenceStorage(
            @Value("${app.evidence.minio.endpoint}") String endpoint,
            @Value("${app.evidence.minio.access-key}") String accessKey,
            @Value("${app.evidence.minio.secret-key}") String secretKey,
            @Value("${app.evidence.minio.bucket:safefleet-evidence}") String bucket) {
        this.client = MinioClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .build();
        this.bucket = bucket;
    }

    @PostConstruct
    void ensurePrivateBucket() throws IOException {
        try {
            if (!client.bucketExists(BucketExistsArgs.builder().bucket(bucket).build())) {
                client.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
            }
        } catch (Exception exception) {
            throw storageFailure("Không thể khởi tạo bucket evidence", exception);
        }
    }

    @Override
    public void store(String objectKey, MultipartFile file) throws IOException {
        try (var input = file.getInputStream()) {
            client.putObject(
                    PutObjectArgs.builder()
                            .bucket(bucket)
                            .object(objectKey)
                            .contentType(file.getContentType())
                            .stream(input, file.getSize(), -1L)
                            .build()
            );
        } catch (Exception exception) {
            throw storageFailure("Không thể upload evidence lên object storage", exception);
        }
    }

    @Override
    public Resource load(String objectKey) throws IOException {
        try {
            var response = client.getObject(
                    GetObjectArgs.builder().bucket(bucket).object(objectKey).build()
            );
            return new InputStreamResource(response) {
                @Override
                public String getFilename() {
                    return objectKey;
                }
            };
        } catch (ErrorResponseException exception) {
            if ("NoSuchKey".equals(exception.errorResponse().code())
                    || "NoSuchObject".equals(exception.errorResponse().code())) {
                throw new FileNotFoundException(objectKey);
            }
            throw storageFailure("Không thể tải evidence từ object storage", exception);
        } catch (Exception exception) {
            throw storageFailure("Không thể tải evidence từ object storage", exception);
        }
    }

    @Override
    public void delete(String objectKey) throws IOException {
        try {
            client.removeObject(
                    RemoveObjectArgs.builder().bucket(bucket).object(objectKey).build()
            );
        } catch (Exception exception) {
            throw storageFailure("Không thể xóa evidence khỏi object storage", exception);
        }
    }

    private IOException storageFailure(String message, Exception cause) {
        return new IOException(message, cause);
    }
}
