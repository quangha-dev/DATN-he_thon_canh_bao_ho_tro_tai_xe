package com.safefleet.common.exception;

import org.springframework.http.HttpStatus;

public class TooManyRequestsException extends BusinessException {

    public TooManyRequestsException(String message) {
        super(HttpStatus.TOO_MANY_REQUESTS, message);
    }
}
