package com.stepuphub.repository;

import com.stepuphub.domain.ApprovalStatus;
import com.stepuphub.domain.TeacherCourseEnrollment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface TeacherCourseEnrollmentRepository extends JpaRepository<TeacherCourseEnrollment, Long> {
    List<TeacherCourseEnrollment> findByCourseIdAndStatus(Long courseId, ApprovalStatus status);
    List<TeacherCourseEnrollment> findByTeacherId(Long teacherId);
    List<TeacherCourseEnrollment> findByStatus(ApprovalStatus status);
    Optional<TeacherCourseEnrollment> findByTeacherIdAndCourseId(Long teacherId, Long courseId);
}
