package com.stepuphub.service;

import com.stepuphub.domain.Course;
import com.stepuphub.domain.CourseCoordinator;
import com.stepuphub.domain.Role;
import com.stepuphub.domain.User;
import com.stepuphub.dto.CourseDto;
import com.stepuphub.dto.UserSummaryDto;
import com.stepuphub.repository.CourseCoordinatorRepository;
import com.stepuphub.repository.CourseRepository;
import com.stepuphub.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Course-level coordinator assignment: a course may have several coordinators, each covering every
 * class in it (replaces the old one-coordinator-per-class-session model).
 */
@Service
@RequiredArgsConstructor
public class CourseCoordinatorService {

    private final CourseCoordinatorRepository courseCoordinatorRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;

    private User requireAdmin(Long adminId) {
        User admin = userRepository.findById(adminId).orElseThrow(() -> new IllegalArgumentException("Admin not found"));
        if (admin.getRole() != Role.ADMIN) throw new IllegalArgumentException("Only admins can manage coordinator assignments");
        return admin;
    }

    @Transactional
    public UserSummaryDto assign(Long adminId, Long courseId, Long coordinatorId) {
        requireAdmin(adminId);
        Course course = courseRepository.findById(courseId).orElseThrow(() -> new IllegalArgumentException("Course not found"));
        User coordinator = userRepository.findById(coordinatorId).orElseThrow(() -> new IllegalArgumentException("Coordinator not found"));
        if (coordinator.getRole() != Role.COORDINATOR) throw new IllegalArgumentException("User is not a coordinator");
        if (courseCoordinatorRepository.existsByCourseIdAndCoordinatorId(courseId, coordinatorId)) {
            throw new IllegalArgumentException(coordinator.getName() + " is already assigned to this course");
        }
        CourseCoordinator cc = new CourseCoordinator();
        cc.setCourse(course);
        cc.setCoordinator(coordinator);
        courseCoordinatorRepository.save(cc);
        return UserSummaryDto.from(coordinator);
    }

    @Transactional
    public void unassign(Long adminId, Long courseId, Long coordinatorId) {
        requireAdmin(adminId);
        CourseCoordinator cc = courseCoordinatorRepository.findByCourseIdAndCoordinatorId(courseId, coordinatorId)
                .orElseThrow(() -> new IllegalArgumentException("This coordinator isn't assigned to this course"));
        courseCoordinatorRepository.delete(cc);
    }

    @Transactional(readOnly = true)
    public List<UserSummaryDto> listForCourse(Long courseId) {
        return courseCoordinatorRepository.findByCourseId(courseId).stream()
                .map(cc -> UserSummaryDto.from(cc.getCoordinator())).toList();
    }

    @Transactional(readOnly = true)
    public List<CourseDto> listCoursesForCoordinator(Long coordinatorId) {
        return courseCoordinatorRepository.findByCoordinatorId(coordinatorId).stream()
                .map(cc -> CourseDto.from(cc.getCourse())).toList();
    }
}
