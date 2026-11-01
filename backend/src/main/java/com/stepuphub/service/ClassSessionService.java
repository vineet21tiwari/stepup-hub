package com.stepuphub.service;

import com.stepuphub.domain.ClassSession;
import com.stepuphub.domain.Notification;
import com.stepuphub.domain.Role;
import com.stepuphub.domain.StudentAttendance;
import com.stepuphub.domain.User;
import com.stepuphub.dto.AttendanceRequest;
import com.stepuphub.dto.ClassSessionDto;
import com.stepuphub.dto.StudentAttendanceDto;
import com.stepuphub.repository.ClassSessionRepository;
import com.stepuphub.repository.CourseCoordinatorRepository;
import com.stepuphub.repository.StudentAttendanceRepository;
import com.stepuphub.repository.UserRepository;
import com.stepuphub.util.MeetingLinks;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ClassSessionService {

    private final ClassSessionRepository classSessionRepository;
    private final UserRepository userRepository;
    private final CourseCoordinatorRepository courseCoordinatorRepository;
    private final StudentAttendanceRepository studentAttendanceRepository;
    private final NotificationService notificationService;

    @Value("${app.meeting.join-window-minutes:5}")
    private long joinWindowMinutes;

    private User requireUser(Long userId) {
        return userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));
    }

    private ClassSession requireSession(Long sessionId) {
        return classSessionRepository.findById(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("Session not found"));
    }

    /**
     * Builds the viewer-specific DTO. The teacher and admins always get the meeting link; students and
     * coordinators only get it during the join window (joinWindowMinutes before the start until the end),
     * so the "join 5 minutes before class" rule is enforced here and not just in the UI.
     */
    private ClassSessionDto toDto(ClassSession s, User viewer) {
        Instant now = Instant.now();
        Instant opensAt = s.getScheduledStart().minus(joinWindowMinutes, ChronoUnit.MINUTES);
        boolean host = viewer.getRole() == Role.ADMIN || s.getTeacher().getId().equals(viewer.getId());
        boolean windowOpen = s.getStatus() != ClassSession.SessionStatus.CANCELLED
                && !now.isBefore(opensAt) && now.isBefore(s.getScheduledEnd());
        String visible = (host || windowOpen) ? s.getMeetingLink() : null;
        List<StudentAttendanceDto> attendance = studentAttendanceRepository.findBySessionId(s.getId())
                .stream().map(StudentAttendanceDto::from).toList();
        return ClassSessionDto.from(s, visible, opensAt, attendance);
    }

    @Transactional(readOnly = true)
    public List<ClassSessionDto> forCurrentUser(Long userId) {
        User u = requireUser(userId);
        List<ClassSession> sessions = switch (u.getRole()) {
            case STUDENT -> classSessionRepository.findByStudents_Id(userId);
            case TEACHER -> classSessionRepository.findByTeacherId(userId);
            // A coordinator's classes are every session under the courses they're assigned to.
            case COORDINATOR -> {
                List<Long> courseIds = courseCoordinatorRepository.findByCoordinatorId(userId).stream()
                        .map(cc -> cc.getCourse().getId()).toList();
                yield courseIds.isEmpty() ? List.of() : classSessionRepository.findByCourseIdIn(courseIds);
            }
            case ADMIN -> classSessionRepository.findAll();
        };
        return sessions.stream().map(s -> toDto(s, u)).toList();
    }

    /** The current user's classes for one course (used by the course page's "Classes" panel). */
    @Transactional(readOnly = true)
    public List<ClassSessionDto> forCourse(Long userId, Long courseId) {
        return forCurrentUser(userId).stream().filter(s -> s.courseId().equals(courseId)).toList();
    }

    @Transactional(readOnly = true)
    public ClassSessionDto get(Long sessionId, Long userId) {
        if (!isParticipant(sessionId, userId)) {
            throw new IllegalArgumentException("You are not part of this class session");
        }
        return toDto(requireSession(sessionId), requireUser(userId));
    }

    /** Verifies the given user is a participant (student/teacher/coordinator of the course) or an admin. Used before allowing chat access. */
    @Transactional(readOnly = true)
    public boolean isParticipant(Long sessionId, Long userId) {
        ClassSession s = requireSession(sessionId);
        if (s.getTeacher().getId().equals(userId)) return true;
        if (s.getStudents().stream().anyMatch(st -> st.getId().equals(userId))) return true;
        if (courseCoordinatorRepository.existsByCourseIdAndCoordinatorId(s.getCourse().getId(), userId)) return true;
        User u = userRepository.findById(userId).orElse(null);
        return u != null && u.getRole() == Role.ADMIN;
    }

    /**
     * The class teacher starts the class by attaching a Zoom or Google Meet link; participants are notified.
     * When this session is one occurrence of a recurring weekly series (same Slot.recurrenceGroupId), the
     * same link is applied to every other still-active occurrence too, so the teacher only pastes it once.
     */
    @Transactional
    public ClassSessionDto setMeetingLink(Long teacherId, Long sessionId, String rawLink) {
        User teacher = requireUser(teacherId);
        ClassSession session = requireSession(sessionId);
        requireClassTeacher(session, teacher);
        if (session.getStatus() == ClassSession.SessionStatus.CANCELLED || session.getStatus() == ClassSession.SessionStatus.COMPLETED) {
            throw new IllegalArgumentException("This class is " + session.getStatus().name().toLowerCase() + " — a meeting link can't be added");
        }
        String link = MeetingLinks.validate(rawLink);
        boolean changed = !link.equals(session.getMeetingLink());
        session.setMeetingLink(link);
        ClassSession saved = classSessionRepository.save(session);

        List<ClassSession> changedSiblings = propagateToSeries(saved, link);

        if (changed) notifyMeetingLinkAdded(saved);
        changedSiblings.forEach(this::notifyMeetingLinkAdded);

        return toDto(saved, teacher);
    }

    @Transactional
    public ClassSessionDto clearMeetingLink(Long teacherId, Long sessionId) {
        User teacher = requireUser(teacherId);
        ClassSession session = requireSession(sessionId);
        requireClassTeacher(session, teacher);
        session.setMeetingLink(null);
        ClassSession saved = classSessionRepository.save(session);
        propagateToSeries(saved, null);
        return toDto(saved, teacher);
    }

    /**
     * Applies `link` to every other still-active (not cancelled/completed) session sharing this session's
     * Slot.recurrenceGroupId, and returns the ones that actually changed (for notification purposes).
     * A no-op for one-off slots (recurrenceGroupId is null).
     */
    private List<ClassSession> propagateToSeries(ClassSession session, String link) {
        if (session.getSlot() == null || session.getSlot().getRecurrenceGroupId() == null) return List.of();
        List<ClassSession> changedSiblings = classSessionRepository
                .findBySlot_RecurrenceGroupId(session.getSlot().getRecurrenceGroupId()).stream()
                .filter(s -> !s.getId().equals(session.getId()))
                .filter(s -> s.getStatus() != ClassSession.SessionStatus.CANCELLED && s.getStatus() != ClassSession.SessionStatus.COMPLETED)
                .filter(s -> !java.util.Objects.equals(link, s.getMeetingLink()))
                .toList();
        changedSiblings.forEach(s -> s.setMeetingLink(link));
        if (!changedSiblings.isEmpty()) classSessionRepository.saveAll(changedSiblings);
        return changedSiblings;
    }

    private void notifyMeetingLinkAdded(ClassSession session) {
        String msg = "Meeting link added for \"" + session.getCourse().getTitle() + "\" — you can join "
                + joinWindowMinutes + " minutes before the class starts";
        String ref = "SESSION:" + session.getId();
        session.getStudents().forEach(st -> notificationService.notify(st, Notification.NotificationType.MEETING_LINK_ADDED, msg, ref));
        courseCoordinatorRepository.findByCourseId(session.getCourse().getId())
                .forEach(cc -> notificationService.notify(cc.getCoordinator(), Notification.NotificationType.MEETING_LINK_ADDED, msg, ref));
    }

    private void requireClassTeacher(ClassSession session, User user) {
        if (!session.getTeacher().getId().equals(user.getId())) {
            throw new IllegalArgumentException("Only this class's teacher can manage its meeting link");
        }
    }

    /**
     * A coordinator (or admin) records how long a class actually ran and who was present, after the
     * fact. Re-marking a session replaces its previous attendance rows. Every student now marked
     * absent is notified, along with the class's teacher — presences don't trigger a notification.
     */
    @Transactional
    public ClassSessionDto markAttendance(Long markerId, Long sessionId, AttendanceRequest req) {
        User marker = requireUser(markerId);
        ClassSession session = requireSession(sessionId);
        boolean allowed = marker.getRole() == Role.ADMIN
                || courseCoordinatorRepository.existsByCourseIdAndCoordinatorId(session.getCourse().getId(), markerId);
        if (!allowed) {
            throw new IllegalArgumentException("Only a coordinator assigned to this course (or an admin) can mark attendance");
        }
        if (!req.getActualEnd().isAfter(req.getActualStart())) {
            throw new IllegalArgumentException("Actual end time must be after actual start time");
        }

        session.setActualStart(req.getActualStart());
        session.setActualEnd(req.getActualEnd());
        session.setTeacherPresent(req.getTeacherPresent());
        session.setAttendanceMarkedAt(Instant.now());
        ClassSession saved = classSessionRepository.save(session);

        studentAttendanceRepository.deleteBySessionId(sessionId);
        List<StudentAttendance> rows = new ArrayList<>();
        List<User> newlyAbsent = new ArrayList<>();
        for (User student : saved.getStudents()) {
            boolean present = Boolean.TRUE.equals(req.getStudentAttendance().get(student.getId()));
            StudentAttendance row = new StudentAttendance();
            row.setSession(saved);
            row.setStudent(student);
            row.setPresent(present);
            rows.add(row);
            if (!present) newlyAbsent.add(student);
        }
        studentAttendanceRepository.saveAll(rows);

        String courseTitle = saved.getCourse().getTitle();
        newlyAbsent.forEach(student -> {
            notificationService.notify(student, Notification.NotificationType.GENERAL,
                    "You were marked absent for \"" + courseTitle + "\" on " + saved.getScheduledStart(),
                    "SESSION:" + saved.getId());
            notificationService.notify(saved.getTeacher(), Notification.NotificationType.GENERAL,
                    student.getName() + " was absent from \"" + courseTitle + "\" on " + saved.getScheduledStart(),
                    "SESSION:" + saved.getId());
        });

        return toDto(saved, marker);
    }
}
