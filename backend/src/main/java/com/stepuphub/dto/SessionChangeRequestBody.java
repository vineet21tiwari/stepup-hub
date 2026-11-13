package com.stepuphub.dto;

import com.stepuphub.domain.SessionChangeRequest;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.Instant;

@Data
public class SessionChangeRequestBody {
    @NotNull
    private SessionChangeRequest.ChangeType type;
    // Required for RESCHEDULE.
    private Instant newStart;
    private Instant newEnd;
    private String reason;
}
