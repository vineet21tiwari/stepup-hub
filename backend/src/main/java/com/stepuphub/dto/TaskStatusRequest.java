package com.stepuphub.dto;

import com.stepuphub.domain.Task;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class TaskStatusRequest {
    @NotNull
    private Task.TaskStatus status;
}
