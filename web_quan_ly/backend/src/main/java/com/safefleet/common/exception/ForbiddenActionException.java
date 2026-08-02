package com.safefleet.common.exception;

import org.springframework.http.HttpStatus;

public class ForbiddenActionException extends BusinessException {

    public ForbiddenActionException(String message) {
        super(HttpStatus.FORBIDDEN, message);
    }
}
