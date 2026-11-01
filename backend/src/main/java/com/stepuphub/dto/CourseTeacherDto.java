package com.stepuphub.dto;

import com.stepuphub.domain.TeacherCourseEnrollment;

// Resume is intentionally left out here: this DTO backs the student-facing "pick a teacher for this
// course" listing, and resumes are only for Admin review (see TeacherApplicationDto / AdminTeacherApplications).
public record CourseTeacherDto(Long applicationId, Long teacherId, String teacherName, String teacherExtraInfo,
                                String introVideoUrl) {
    public static CourseTeacherDto from(TeacherCourseEnrollment e) {
        return new CourseTeacherDto(e.getId(), e.getTeacher().getId(), e.getTeacher().getName(),
                e.getTeacher().getExtraInfo(), e.getIntroVideoUrl());
    }
}