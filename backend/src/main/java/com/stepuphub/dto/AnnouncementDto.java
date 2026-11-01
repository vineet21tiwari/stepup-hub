package com.stepuphub.dto;

import com.stepuphub.domain.Announcement;

import java.time.Instant;

public record AnnouncementDto(Long id, String title, String message, String scope,
                               Long courseId, String courseTitle,
                               Long createdById, String createdByName, String createdByRole, Instant createdAt) {
    public static AnnouncementDto from(Announcement a) {
        return new AnnouncementDto(
                a.getId(),
                a.getTitle(),
                a.getMessage(),
                a.getScope().name(),
                a.getCourse() != null ? a.getCourse().getId() : null,
                a.getCourse() != null ? a.getCourse().getTitle() : null,
                a.getCreatedBy().getId(),
                a.getCreatedBy().getName(),
                a.getCreatedBy().getRole().name(),
                a.getCreatedAt()
        );
    }
}
