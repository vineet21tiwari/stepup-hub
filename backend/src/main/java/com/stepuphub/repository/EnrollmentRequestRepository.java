package com.stepuphub.repository;

import com.stepuphub.domain.EnrollmentRequest;
import com.stepuphub.domain.RequestStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface EnrollmentRequestRepository extends JpaRepository<EnrollmentRequest, Long> {
    List<EnrollmentRequest> findByStudentId(Long studentId);
    List<EnrollmentRequest> findBySlotTeacherIdAndStatus(Long teacherId, RequestStatus status);
    List<EnrollmentRequest> findByStatus(RequestStatus status);
    List<EnrollmentRequest> findByStudentIdAndSlotCourseIdAndStatusIn(Long studentId, Long courseId, List<RequestStatus> statuses);
    List<EnrollmentRequest> findBySlotCourseIdAndStatus(Long courseId, RequestStatus status);
    // Used to enforce "one class per calendar day" across ALL of a student's courses.
    List<EnrollmentRequest> findByStudentIdAndStatusIn(Long studentId, List<RequestStatus> statuses);
    // Used to approve/reject an entire weekly-commitment submission as one unit.
    List<EnrollmentRequest> findByBatchId(String batchId);
}
