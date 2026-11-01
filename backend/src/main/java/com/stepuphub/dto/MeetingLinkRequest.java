package com.stepuphub.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class MeetingLinkRequest {
    @NotBlank
    private String meetingLink;
}
