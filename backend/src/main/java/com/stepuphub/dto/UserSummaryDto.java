package com.stepuphub.dto;

import com.stepuphub.domain.User;

public record UserSummaryDto(Long id, String name, String email, String phone, String role, String extraInfo,
                              boolean approved, boolean active, String resumeUrl) {
    public static UserSummaryDto from(User u) {
        return new UserSummaryDto(u.getId(), u.getName(), u.getEmail(), u.getPhone(),
                u.getRole().name(), u.getExtraInfo(), u.isApproved(), u.isActive(), u.getResumeUrl());
    }
}
