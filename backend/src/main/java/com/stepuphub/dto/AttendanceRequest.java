package com.stepuphub.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.Instant;
import java.util.Map;

@Data
public class AttendanceRequest {
    @NotNull
    private Instant actualStart;

    @NotNull
    private Instant actualEnd;

    @NotNull
    private Boolean teacherPresent;

    // studentId -> present
    @NotNull
    private Map<Long, Boolean> studentAttendance;
}
