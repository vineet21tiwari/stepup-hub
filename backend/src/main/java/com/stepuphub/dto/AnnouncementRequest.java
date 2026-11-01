package com.stepuphub.dto;

import com.stepuphub.domain.AnnouncementScope;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class AnnouncementRequest {
    @NotBlank
    private String title;

    @NotBlank
    private String message;

    @NotNull
    private AnnouncementScope scope;

    // Required when scope == COURSE, ignored otherwise
    private Long courseId;
}