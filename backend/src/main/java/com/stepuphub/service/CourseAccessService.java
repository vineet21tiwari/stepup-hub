package com.stepuphub.service;

import com.stepuphub.domain.ApprovalStatus;
import com.stepuphub.domain.RequestStatus;
import com.stepuphub.domain.Role;
import com.stepuphub.domain.User;
import com.stepuphub.repository.CourseCoordinatorRepository;
import com.stepuphub.repository.EnrollmentRequestRepository;
import com.stepuphub.repository.TeacherCourseEnrollmentRepository;
import com.stepuphub.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Who belongs to a course's classroom (posts, assignments, class meeting links):
 * admins; teachers approved for the course; students with an approved booking in it;
 * and coordinators assigned to the course itself (course-level assignment — see CourseCoordinatorService).
 * "Managers" (teacher approved for the course, or admin) may add announcements and assignments.
 */
@Service
@RequiredArgsConstructor
public class CourseAccessService {

    private final UserRepository userRepository;
    private final TeacherCourseEnrollmentRepository tceRepository;
    private final EnrollmentRequestRepository enrollmentRequestRepository;
    private final CourseCoordinatorRepository courseCoordinatorRepository;

    public User requireUser(Long userId) {
        return userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));
    }

    @Transactional(readOnly = true)
    public boolean isMember(Long courseId, User user) {
        return switch (user.getRole()) {
            case ADMIN -> true;
            case TEACHER -> isApprovedTeacher(courseId, user.getId());
            case STUDENT -> !enrollmentRequestRepository.findByStudentIdAndSlotCourseIdAndStatusIn(
                    user.getId(), courseId, List.of(RequestStatus.APPROVED)).isEmpty();
            case COORDINATOR -> courseCoordinatorRepository.existsByCourseIdAndCoordinatorId(courseId, user.getId());
        };
    }

    @Transactional(readOnly = true)
    public boolean canManage(Long courseId, User user) {
        return user.getRole() == Role.ADMIN || (user.getRole() == Role.TEACHER && isApprovedTeacher(courseId, user.getId()));
    }

    @Transactional(readOnly = true)
    public User requireMember(Long courseId, Long userId) {
        User user = requireUser(userId);
        if (!isMember(courseId, user)) {
            throw new IllegalArgumentException("You are not part of this course");
        }
        return user;
    }

    private boolean isApprovedTeacher(Long courseId, Long teacherId) {
        return tceRepository.findByTeacherIdAndCourseId(teacherId, courseId)
                .filter(e -> e.getStatus() == ApprovalStatus.APPROVED)
                .isPresent();
    }
}
