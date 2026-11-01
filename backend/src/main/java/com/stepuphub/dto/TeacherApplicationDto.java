package com.stepuphub.dto;

import com.stepuphub.domain.TeacherCourseEnrollment;

import java.time.Instant;

public record TeacherApplicationDto(Long id, Long teacherId, String teacherName, String teacherExtraInfo,
                                     String resumeUrl, Long courseId, String courseTitle, String status,
                                     String introVideoUrl, Instant createdAt) {
    public static TeacherApplicationDto from(TeacherCourseEnrollment e) {
        return new TeacherApplicationDto(e.getId(), e.getTeacher().getId(), e.getTeacher().getName(),
                e.getTeacher().getExtraInfo(), e.getTeacher().getResumeUrl(), e.getCourse().getId(), e.getCourse().getTitle(),
                e.getStatus().name(), e.getIntroVideoUrl(), e.getCreatedAt());
    }
}
