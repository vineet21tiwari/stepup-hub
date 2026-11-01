package com.stepuphub.dto;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.Instant;

@Data
public class SlotRequest {
    @NotNull
    private Long courseId;
    @NotNull
    private Instant startTime;
    @NotNull
    private Instant endTime;
    private Integer capacity = 1;
}
