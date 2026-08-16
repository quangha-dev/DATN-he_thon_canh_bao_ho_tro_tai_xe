package com.safefleet.mobile.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.mobile.dto.request.DocumentPlateReviewRequest;
import com.safefleet.mobile.dto.response.DocumentPlateReviewResponse;
import com.safefleet.mobile.enums.PlateReviewStatus;
import com.safefleet.mobile.service.DocumentPlateReviewService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;

@Tag(name = "Document plate reviews", description = "Manager review for OCR vehicle plate mismatches")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/document-reviews")
@PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
public class DocumentPlateReviewController {

    private final DocumentPlateReviewService service;

    @Operation(summary = "List OCR documents by plate review status")
    @GetMapping
    public ApiResponse<PageResponse<DocumentPlateReviewResponse>> list(
            @RequestParam(defaultValue = "REVIEW_REQUIRED") PlateReviewStatus status,
            Pageable pageable) {
        return ApiResponse.ok(service.list(status, pageable));
    }

    @GetMapping("/{id}")
    public ApiResponse<DocumentPlateReviewResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(service.get(id));
    }

    @GetMapping("/{id}/image")
    public ResponseEntity<byte[]> image(@PathVariable Long id) {
        DocumentPlateReviewService.ReviewImage image = service.image(id);
        MediaType type;
        try {
            type = MediaType.parseMediaType(image.contentType());
        } catch (Exception ignored) {
            type = MediaType.APPLICATION_OCTET_STREAM;
        }
        return ResponseEntity.ok()
                .contentType(type)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.inline()
                                .filename(image.filename() == null ? "voucher.jpg" : image.filename(),
                                        StandardCharsets.UTF_8)
                                .build().toString())
                .body(image.bytes());
    }

    @PostMapping("/{id}/approve")
    public ApiResponse<DocumentPlateReviewResponse> approve(
            @PathVariable Long id,
            @Valid @RequestBody(required = false) DocumentPlateReviewRequest request) {
        return ApiResponse.ok("Đã xác nhận phiếu", service.approve(id, request == null ? null : request.note()));
    }

    @PostMapping("/{id}/reject")
    public ApiResponse<DocumentPlateReviewResponse> reject(
            @PathVariable Long id,
            @Valid @RequestBody(required = false) DocumentPlateReviewRequest request) {
        return ApiResponse.ok("Đã từ chối phiếu", service.reject(id, request == null ? null : request.note()));
    }
}
