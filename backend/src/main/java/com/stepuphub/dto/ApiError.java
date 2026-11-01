package com.stepuphub.dto;

import java.time.Instant;

public record ApiError(String message, Instant timestamp) {
    public ApiError(String message) {
        this(message, Instant.now());
    }
}
