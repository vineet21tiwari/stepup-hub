package com.stepuphub.dto;

import com.stepuphub.domain.EnrollmentRequest;

import java.time.Instant;

public record EnrollmentRequestDto(Long id, Long studentId, String studentName, String studentEmail,
                                    String studentPhone, String studentExtraInfo, Long slotId,
                                    Long teacherId, String teacherName, Long courseId, String courseTitle,
                                    Instant slotStart, Instant slotEnd, String status, Instant createdAt,
                                    String batchId) {
    public static EnrollmentRequestDto from(EnrollmentRequest r) {
        return new EnrollmentRequestDto(
                r.getId(), r.getStudent().getId(), r.getStudent().getName(), r.getStudent().getEmail(),
                r.getStudent().getPhone(), r.getStudent().getExtraInfo(),
                r.getSlot().getId(), r.getSlot().getTeacher().getId(), r.getSlot().getTeacher().getName(),
                r.getSlot().getCourse().getId(), r.getSlot().getCourse().getTitle(),
                r.getSlot().getStartTime(), r.getSlot().getEndTime(),
                r.getStatus().name(), r.getCreatedAt(), r.getBatchId());
    }
}
