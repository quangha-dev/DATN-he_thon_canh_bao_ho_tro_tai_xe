package com.safefleet.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@Configuration
public class OcrTaskExecutorConfig {

    @Bean("ocrTaskExecutor")
    public TaskExecutor ocrTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        // VietOCR resident model và Tesseract dùng nhiều RAM; xử lý tuần tự giúp
        // kết quả ổn định khi nhiều điện thoại gửi phiếu cùng lúc.
        executor.setCorePoolSize(1);
        executor.setMaxPoolSize(1);
        executor.setQueueCapacity(50);
        executor.setThreadNamePrefix("document-ocr-");
        executor.initialize();
        return executor;
    }
}
