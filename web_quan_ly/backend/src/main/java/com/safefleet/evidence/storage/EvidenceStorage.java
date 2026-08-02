package com.safefleet.evidence.storage;

import org.springframework.core.io.Resource;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

public interface EvidenceStorage {

    void store(String objectKey, MultipartFile file) throws IOException;

    Resource load(String objectKey) throws IOException;

    void delete(String objectKey) throws IOException;
}
