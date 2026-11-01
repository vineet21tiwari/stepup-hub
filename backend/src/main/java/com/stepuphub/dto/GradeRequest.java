package com.stepuphub.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class GradeRequest {
    @NotBlank
    private String grade;
    private String feedback;
}