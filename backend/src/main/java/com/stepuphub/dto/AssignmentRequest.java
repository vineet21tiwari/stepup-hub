package com.stepuphub.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.Instant;

@Data
public class AssignmentRequest {
    @NotBlank
    private String title;

    private String description;

    @NotNull
    private Long courseId;

    @NotNull
    private Instant dueDate;
}
