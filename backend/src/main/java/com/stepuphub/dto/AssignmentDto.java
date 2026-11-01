package com.stepuphub.dto;

import com.stepuphub.domain.Assignment;

import java.time.Instant;

/** teacherId/teacherName identify the author, who is the course teacher or an admin (see authorRole). */
public record AssignmentDto(Long id, String title, String description, Long courseId, String courseTitle,
                             Long teacherId, String teacherName, String authorRole, Instant dueDate,
                             String attachmentUrl, Instant createdAt) {
    public static AssignmentDto from(Assignment a) {
        return new AssignmentDto(a.getId(), a.getTitle(), a.getDescription(),
                a.getCourse().getId(), a.getCourse().getTitle(),
                a.getTeacher().getId(), a.getTeacher().getName(), a.getTeacher().getRole().name(),
                a.getDueDate(), a.getAttachmentUrl(), a.getCreatedAt());
    }
}
