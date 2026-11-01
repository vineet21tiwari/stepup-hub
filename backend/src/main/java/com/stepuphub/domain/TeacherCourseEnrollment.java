package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * A teacher's application to teach a given Course.
 * Once APPROVED by admin, the teacher shows up on that course's teacher list
 * and their Slots for that course become bookable by students.
 */
@Entity
@Table(name = "teacher_course_enrollments")
@Data
@NoArgsConstructor
public class TeacherCourseEnrollment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "teacher_id")
    private User teacher;

    @ManyToOne(optional = false)
    @JoinColumn(name = "course_id")
    private Course course;

    @Enumerated(EnumType.STRING)
    private ApprovalStatus status = ApprovalStatus.PENDING;

    // Short intro video the teacher records for this course application, so students
    // can watch it before deciding which teacher to book for the course.
    private String introVideoUrl;

    @ManyToOne
    @JoinColumn(name = "reviewed_by_admin_id")
    private User reviewedBy;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();
}
