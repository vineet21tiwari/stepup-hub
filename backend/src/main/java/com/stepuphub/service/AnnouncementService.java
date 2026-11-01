package com.stepuphub.service;

import com.stepuphub.domain.*;
import com.stepuphub.dto.AnnouncementDto;
import com.stepuphub.dto.AnnouncementRequest;
import com.stepuphub.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * Announcements. Admins can post GLOBAL ones (notify every user) or COURSE ones. Teachers approved for a
 * course can post COURSE ones for it. COURSE announcements notify that course's approved teachers, students
 * with an approved enrollment in the course, and coordinators assigned to any of its sessions.
 */
@Service
@RequiredArgsConstructor
public class AnnouncementService {

    private final AnnouncementRepository announcementRepository;
    private final UserRepository userRepository;
    private final CourseRepository courseRepository;
    private final TeacherCourseEnrollmentRepository tceRepository;
    private final EnrollmentRequestRepository enrollmentRequestRepository;
    private final CourseCoordinatorRepository courseCoordinatorRepository;
    private final NotificationService notificationService;
    private final CourseAccessService courseAccessService;

    @Transactional
    public AnnouncementDto create(Long authorId, AnnouncementRequest req) {
        User author = userRepository.findById(authorId).orElseThrow(() -> new IllegalArgumentException("User not found"));
        boolean isAdmin = author.getRole() == Role.ADMIN;
        if (!isAdmin && author.getRole() != Role.TEACHER) {
            throw new IllegalArgumentException("Only admins and teachers can create announcements");
        }
        if (!isAdmin && req.getScope() != AnnouncementScope.COURSE) {
            throw new IllegalArgumentException("Teachers can only post announcements for their own courses");
        }

        Announcement a = new Announcement();
        a.setTitle(req.getTitle());
        a.setMessage(req.getMessage());
        a.setScope(req.getScope());
        a.setCreatedBy(author);

        Set<User> recipients = new LinkedHashSet<>();

        if (req.getScope() == AnnouncementScope.COURSE) {
            if (req.getCourseId() == null) {
                throw new IllegalArgumentException("courseId is required for a course-level announcement");
            }
            Course course = courseRepository.findById(req.getCourseId())
                    .orElseThrow(() -> new IllegalArgumentException("Course not found"));
            if (!courseAccessService.canManage(course.getId(), author)) {
                throw new IllegalArgumentException("You must be an approved teacher for this course to post announcements");
            }
            a.setCourse(course);

            tceRepository.findByCourseIdAndStatus(course.getId(), ApprovalStatus.APPROVED)
                    .forEach(tce -> recipients.add(tce.getTeacher()));

            enrollmentRequestRepository.findBySlotCourseIdAndStatus(course.getId(), RequestStatus.APPROVED)
                    .forEach(er -> recipients.add(er.getStudent()));

            courseCoordinatorRepository.findByCourseId(course.getId())
                    .forEach(cc -> recipients.add(cc.getCoordinator()));
        } else {
            recipients.addAll(userRepository.findAll());
        }
        recipients.remove(author);

        Announcement saved = announcementRepository.save(a);

        String prefix = "[" + saved.getTitle() + "] ";
        recipients.forEach(user -> notificationService.notify(user, Notification.NotificationType.ANNOUNCEMENT,
                prefix + saved.getMessage(), "ANNOUNCEMENT:" + saved.getId()));

        return AnnouncementDto.from(saved);
    }

    @Transactional(readOnly = true)
    public List<AnnouncementDto> listAll() {
        return announcementRepository.findAllByOrderByCreatedAtDesc().stream().map(AnnouncementDto::from).toList();
    }

    @Transactional(readOnly = true)
    public AnnouncementDto get(Long id) {
        return AnnouncementDto.from(announcementRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Announcement not found")));
    }

    // Admins can edit any announcement; teachers only ones they posted. Edits the text only; scope/course are
    // fixed at creation time since changing them would require re-deriving (and re-notifying) a different recipient set.
    @Transactional
    public AnnouncementDto update(Long userId, Long announcementId, AnnouncementRequest req) {
        Announcement a = requireEditable(userId, announcementId, "edit");
        a.setTitle(req.getTitle());
        a.setMessage(req.getMessage());
        return AnnouncementDto.from(announcementRepository.save(a));
    }

    @Transactional
    public void delete(Long userId, Long announcementId) {
        announcementRepository.delete(requireEditable(userId, announcementId, "delete"));
    }

    private Announcement requireEditable(Long userId, Long announcementId, String verb) {
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));
        Announcement a = announcementRepository.findById(announcementId)
                .orElseThrow(() -> new IllegalArgumentException("Announcement not found"));
        boolean owner = a.getCreatedBy().getId().equals(userId);
        if (user.getRole() != Role.ADMIN && !(user.getRole() == Role.TEACHER && owner)) {
            throw new IllegalArgumentException("You can only " + verb + " announcements you posted");
        }
        return a;
    }

    @Transactional(readOnly = true)
    public List<AnnouncementDto> listGlobal() {
        return announcementRepository.findByScopeOrderByCreatedAtDesc(AnnouncementScope.GLOBAL)
                .stream().map(AnnouncementDto::from).toList();
    }

    @Transactional(readOnly = true)
    public List<AnnouncementDto> listForCourse(Long courseId) {
        return announcementRepository.findByCourseIdOrderByCreatedAtDesc(courseId)
                .stream().map(AnnouncementDto::from).toList();
    }
}
