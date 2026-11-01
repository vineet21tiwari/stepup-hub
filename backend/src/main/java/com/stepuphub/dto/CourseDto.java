package com.stepuphub.dto;

import com.stepuphub.domain.Course;

public record CourseDto(Long id, String title, String description, String subject, boolean active, boolean featured,
                         String curriculumUrl) {
    public static CourseDto from(Course c) {
        return new CourseDto(c.getId(), c.getTitle(), c.getDescription(), c.getSubject(), c.isActive(), c.isFeatured(),
                c.getCurriculumUrl());
    }
}
