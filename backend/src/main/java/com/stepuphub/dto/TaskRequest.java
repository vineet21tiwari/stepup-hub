package com.stepuphub.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.Instant;

@Data
public class TaskRequest {
    @NotBlank
    private String title;

    private String description;

    // Optional — a task can stand alone or be tied to a specific course.
    private Long courseId;

    @NotNull
    private Long coordinatorId;

    @NotNull
    private Instant deadline;
}
