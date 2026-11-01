package com.stepuphub.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class TestimonialRequest {
    @NotBlank
    private String authorName;

    private String authorRole;

    @NotBlank
    private String message;

    private Integer rating;
    private boolean published = true;
    private int displayOrder = 0;
}