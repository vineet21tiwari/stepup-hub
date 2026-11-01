package com.stepuphub.service;

import com.stepuphub.domain.ApprovalStatus;
import com.stepuphub.domain.Course;
import com.stepuphub.domain.Role;
import com.stepuphub.domain.User;
import com.stepuphub.dto.CourseDto;
import com.stepuphub.dto.CourseRequest;
import com.stepuphub.dto.CourseTeacherDto;
import com.stepuphub.repository.CourseRepository;
import com.stepuphub.repository.TeacherCourseEnrollmentRepository;
import com.stepuphub.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@Service
@RequiredArgsConstructor
public class
CourseService {

    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final TeacherCourseEnrollmentRepository tceRepository;
    private final FileStorageService fileStorageService;

    @Transactional
    public CourseDto createCourse(Long adminId, CourseRequest req, MultipartFile curriculum) {
        User admin = userRepository.findById(adminId).orElseThrow(() -> new IllegalArgumentException("Admin not found"));
        if (admin.getRole() != Role.ADMIN) {
            throw new IllegalArgumentException("Only admins can create courses");
        }
        Course c = new Course();
        c.setTitle(req.getTitle());
        c.setDescription(req.getDescription());
        c.setSubject(req.getSubject());
        c.setFeatured(req.isFeatured());
        c.setCreatedBy(admin);
        if (curriculum != null && !curriculum.isEmpty()) {
            c.setCurriculumUrl(fileStorageService.store("curricula", curriculum));
        }
        return CourseDto.from(courseRepository.save(c));
    }

    @Transactional
    public CourseDto updateCourse(Long adminId, Long courseId, CourseRequest req, MultipartFile curriculum) {
        User admin = userRepository.findById(adminId).orElseThrow(() -> new IllegalArgumentException("Admin not found"));
        if (admin.getRole() != Role.ADMIN) throw new IllegalArgumentException("Only admins can modify courses");
        Course c = courseRepository.findById(courseId).orElseThrow(() -> new IllegalArgumentException("Course not found"));
        c.setTitle(req.getTitle());
        c.setDescription(req.getDescription());
        c.setSubject(req.getSubject());
        c.setFeatured(req.isFeatured());
        if (curriculum != null && !curriculum.isEmpty()) {
            c.setCurriculumUrl(fileStorageService.store("curricula", curriculum));
        }
        return CourseDto.from(courseRepository.save(c));
    }

    @Transactional(readOnly = true)
    public List<CourseDto> listActiveCourses() {
        return courseRepository.findByActiveTrue().stream().map(CourseDto::from).toList();
    }

    @Transactional(readOnly = true)
    public List<CourseDto> listFeaturedCourses() {
        return courseRepository.findByActiveTrueAndFeaturedTrue().stream().map(CourseDto::from).toList();
    }

    @Transactional(readOnly = true)
    public CourseDto getCourse(Long id) {
        return CourseDto.from(courseRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Course not found")));
    }

    @Transactional
    public void deactivateCourse(Long adminId, Long courseId) {
        User admin = userRepository.findById(adminId).orElseThrow();
        if (admin.getRole() != Role.ADMIN) throw new IllegalArgumentException("Only admins can modify courses");
        Course c = courseRepository.findById(courseId).orElseThrow(() -> new IllegalArgumentException("Course not found"));
        c.setActive(false);
        courseRepository.save(c);
    }

    /** Teachers approved to teach a given course, with their resume + this course's intro video (students browsing a course). */
    @Transactional(readOnly = true)
    public List<CourseTeacherDto> approvedTeachersForCourse(Long courseId) {
        return tceRepository.findByCourseIdAndStatus(courseId, ApprovalStatus.APPROVED)
                .stream().filter(tce -> tce.getTeacher().isActive())
                .map(CourseTeacherDto::from).toList();
    }
}
