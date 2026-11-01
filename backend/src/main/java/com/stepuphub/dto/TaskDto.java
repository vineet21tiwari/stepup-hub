package com.stepuphub.dto;

import com.stepuphub.domain.Task;

import java.time.Instant;

public record TaskDto(Long id, String title, String description, Long courseId, String courseTitle,
                       Long assignedById, String assignedByName, Long coordinatorId, String coordinatorName,
                       Instant deadline, String status, Instant createdAt) {
    public static TaskDto from(Task t) {
        return new TaskDto(t.getId(), t.getTitle(), t.getDescription(),
                t.getCourse() != null ? t.getCourse().getId() : null,
                t.getCourse() != null ? t.getCourse().getTitle() : null,
                t.getAssignedBy().getId(), t.getAssignedBy().getName(),
                t.getCoordinator().getId(), t.getCoordinator().getName(),
                t.getDeadline(), t.getStatus().name(), t.getCreatedAt());
    }
}
