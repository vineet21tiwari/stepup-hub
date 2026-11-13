package com.stepuphub.service;

import com.stepuphub.domain.*;
import com.stepuphub.domain.SessionChangeRequest.ChangeStatus;
import com.stepuphub.domain.SessionChangeRequest.ChangeType;
import com.stepuphub.dto.SessionChangeRequestBody;
import com.stepuphub.dto.SessionChangeRequestDto;
import com.stepuphub.repository.*;
import com.stepuphub.util.AppTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Reschedule / cancel requests for a single scheduled class — see SessionChangeRequest for the rules.
 */
@Service
@RequiredArgsConstructor
public class SessionChangeService {

    private static final DateTimeFormatter WHEN = DateTimeFormatter.ofPattern("EEE, MMM d h:mm a").withZone(AppTime.ZONE);

    private final SessionChangeRequestRepository changeRepository;
    private final ClassSessionRepository classSessionRepository;
    private final SlotRepository slotRepository;
    private final UserRepository userRepository;
    private final CourseCoordinatorRepository courseCoordinatorRepository;
    private final NotificationService notificationService;

    /** A class can be changed/cancelled only if it's still scheduled and falls on a later day than today. */
    public static boolean changeAllowed(ClassSession s) {
        if (s.getStatus() != ClassSession.SessionStatus.SCHEDULED) return false;
        LocalDate today = LocalDate.now(AppTime.ZONE);
        LocalDate classDay = s.getScheduledStart().atZone(AppTime.ZONE).toLocalDate();
        return classDay.isAfter(today);
    }

    private User requireUser(Long id) {
        return userRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("User not found"));
    }

    private static Set<Long> parseIds(String csv) {
        if (csv == null || csv.isBlank()) return new LinkedHashSet<>();
        return Arrays.stream(csv.split(",")).filter(s -> !s.isBlank()).map(Long::valueOf)
                .collect(Collectors.toCollection(LinkedHashSet::new));
    }

    @Transactional
    public SessionChangeRequestDto create(Long userId, Long sessionId, SessionChangeRequestBody body) {
        User user = requireUser(userId);
        ClassSession session = classSessionRepository.findById(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("Class not found"));

        boolean isTeacher = session.getTeacher().getId().equals(userId);
        boolean isStudent = session.getStudents().stream().anyMatch(st -> st.getId().equals(userId));
        if (!isTeacher && !isStudent) {
            throw new IllegalArgumentException("Only the class teacher or its student can request a change");
        }
        if (!changeAllowed(session)) {
            throw new IllegalArgumentException("Classes can only be changed or cancelled up to the day before — not on the day of the class");
        }
        if (!changeRepository.findBySessionIdAndStatus(sessionId, ChangeStatus.PENDING).isEmpty()) {
            throw new IllegalArgumentException("There's already a pending change request for this class");
        }

        SessionChangeRequest r = new SessionChangeRequest();
        r.setSession(session);
        r.setRequestedBy(user);
        r.setRequesterRole(isTeacher ? Role.TEACHER : Role.STUDENT);
        r.setType(body.getType());
        r.setReason(body.getReason());
        r.setOriginalStart(session.getScheduledStart());
        r.setOriginalEnd(session.getScheduledEnd());

        if (body.getType() == ChangeType.RESCHEDULE) {
            if (body.getNewStart() == null || body.getNewEnd() == null) {
                throw new IllegalArgumentException("Pick the new date and time");
            }
            if (!body.getNewEnd().isAfter(body.getNewStart())) {
                throw new IllegalArgumentException("New end time must be after the new start time");
            }
            LocalDate newDay = body.getNewStart().atZone(AppTime.ZONE).toLocalDate();
            if (!newDay.isAfter(LocalDate.now(AppTime.ZONE))) {
                throw new IllegalArgumentException("The new time must be on a later day than today");
            }
            if (!isTeacher && session.getStudents().size() > 1) {
                throw new IllegalArgumentException("This is a group class — ask the teacher to reschedule it, or request to cancel your seat");
            }
            r.setNewStart(body.getNewStart());
            r.setNewEnd(body.getNewEnd());
        }
        r = changeRepository.save(r);

        String what = describe(r);
        String ref = "SESSION:" + session.getId();
        if (isTeacher) {
            session.getStudents().forEach(st -> notificationService.notify(st, Notification.NotificationType.GENERAL,
                    user.getName() + " requested to " + what + " — please approve or decline", ref));
        } else {
            notificationService.notify(session.getTeacher(), Notification.NotificationType.GENERAL,
                    user.getName() + " requested to " + what + " — please approve or decline", ref);
        }
        userRepository.findByRole(Role.ADMIN).forEach(a -> notificationService.notify(a, Notification.NotificationType.GENERAL,
                user.getName() + " (" + r_role(isTeacher) + ") requested to " + what + " — needs your approval", ref));
        return toDto(r, user);
    }

    private static String r_role(boolean teacher) {
        return teacher ? "teacher" : "student";
    }

    private String describe(SessionChangeRequest r) {
        ClassSession s = r.getSession();
        String course = "\"" + s.getCourse().getTitle() + "\"";
        if (r.getType() == ChangeType.CANCEL) {
            return "cancel the " + course + " class on " + WHEN.format(r.getOriginalStart());
        }
        return "move the " + course + " class from " + WHEN.format(r.getOriginalStart()) + " to " + WHEN.format(r.getNewStart());
    }

    @Transactional
    public SessionChangeRequestDto decide(Long userId, Long requestId, boolean approve, String note) {
        User user = requireUser(userId);
        SessionChangeRequest r = changeRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("Request not found"));
        if (r.getStatus() != ChangeStatus.PENDING) {
            throw new IllegalArgumentException("This request is already " + r.getStatus().name().toLowerCase());
        }
        if (!awaitingUserIds(r).contains(userId) && !(user.getRole() == Role.ADMIN && !r.isAdminApproved())) {
            throw new IllegalArgumentException("You're not an approver for this request (or you already approved it)");
        }

        String ref = "SESSION:" + r.getSession().getId();
        if (!approve) {
            r.setStatus(ChangeStatus.REJECTED);
            r.setRejectedBy(user);
            r.setDecisionNote(note);
            r.setDecidedAt(Instant.now());
            changeRepository.save(r);
            notificationService.notify(r.getRequestedBy(), Notification.NotificationType.GENERAL,
                    user.getName() + " declined your request to " + describe(r), ref);
            return toDto(r, user);
        }

        if (user.getRole() == Role.ADMIN) {
            r.setAdminApproved(true);
        } else if (r.getRequesterRole() == Role.STUDENT && r.getSession().getTeacher().getId().equals(userId)) {
            r.setTeacherApproved(true);
        } else {
            Set<Long> ids = parseIds(r.getApprovedStudentIds());
            ids.add(userId);
            r.setApprovedStudentIds(ids.stream().map(String::valueOf).collect(Collectors.joining(",")));
        }
        if (note != null && !note.isBlank()) r.setDecisionNote(note);

        if (fullyApproved(r)) {
            if (!changeAllowed(r.getSession())) {
                throw new IllegalArgumentException("It's now the day of the class — this change can no longer be applied");
            }
            apply(r);
            r.setStatus(ChangeStatus.APPROVED);
            r.setDecidedAt(Instant.now());
        }
        changeRepository.save(r);
        return toDto(r, user);
    }

    @Transactional
    public void withdraw(Long userId, Long requestId) {
        SessionChangeRequest r = changeRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("Request not found"));
        if (!r.getRequestedBy().getId().equals(userId)) throw new IllegalArgumentException("Not your request");
        if (r.getStatus() != ChangeStatus.PENDING) throw new IllegalArgumentException("Only a pending request can be withdrawn");
        r.setStatus(ChangeStatus.WITHDRAWN);
        r.setDecidedAt(Instant.now());
        changeRepository.save(r);
    }

    private boolean fullyApproved(SessionChangeRequest r) {
        return r.isAdminApproved() && awaitingUserIds(r).isEmpty();
    }

    /** Non-admin users who still need to approve. */
    private Set<Long> awaitingUserIds(SessionChangeRequest r) {
        Set<Long> out = new LinkedHashSet<>();
        if (r.getStatus() != ChangeStatus.PENDING) return out;
        ClassSession s = r.getSession();
        if (r.getRequesterRole() == Role.TEACHER) {
            Set<Long> approved = parseIds(r.getApprovedStudentIds());
            s.getStudents().stream().map(User::getId).filter(id -> !approved.contains(id)).forEach(out::add);
        } else if (!r.isTeacherApproved()) {
            out.add(s.getTeacher().getId());
        }
        return out;
    }

    private void apply(SessionChangeRequest r) {
        ClassSession s = r.getSession();
        String ref = "SESSION:" + s.getId();
        Set<User> notify = new LinkedHashSet<>(s.getStudents());
        notify.add(s.getTeacher());
        courseCoordinatorRepository.findByCourseId(s.getCourse().getId()).forEach(cc -> notify.add(cc.getCoordinator()));
        String course = "\"" + s.getCourse().getTitle() + "\"";

        if (r.getType() == ChangeType.RESCHEDULE) {
            boolean clash = classSessionRepository.findByTeacherId(s.getTeacher().getId()).stream()
                    .filter(o -> !o.getId().equals(s.getId()))
                    .filter(o -> o.getStatus() == ClassSession.SessionStatus.SCHEDULED)
                    .anyMatch(o -> o.getScheduledStart().isBefore(r.getNewEnd()) && r.getNewStart().isBefore(o.getScheduledEnd()));
            if (clash) {
                throw new IllegalArgumentException("The teacher already has another class at the new time");
            }
            s.setScheduledStart(r.getNewStart());
            s.setScheduledEnd(r.getNewEnd());
            s.setReminderSent(false);
            classSessionRepository.save(s);
            Slot slot = s.getSlot();
            if (slot != null) {
                slot.setStartTime(r.getNewStart());
                slot.setEndTime(r.getNewEnd());
                slotRepository.save(slot);
            }
            String msg = "Class time changed: " + course + " moved from " + WHEN.format(r.getOriginalStart())
                    + " to " + WHEN.format(r.getNewStart());
            notify.forEach(u -> notificationService.notify(u, Notification.NotificationType.SESSION_SCHEDULED, msg, ref));
            return;
        }

        // CANCEL — a student in a group class only gives up their own seat; otherwise the class is cancelled.
        boolean studentLeavingGroup = r.getRequesterRole() == Role.STUDENT && s.getStudents().size() > 1;
        if (studentLeavingGroup) {
            User student = r.getRequestedBy();
            s.getStudents().removeIf(st -> st.getId().equals(student.getId()));
            classSessionRepository.save(s);
            Slot slot = s.getSlot();
            if (slot != null && slot.getBookedCount() > 0) {
                slot.setBookedCount(slot.getBookedCount() - 1);
                slotRepository.save(slot);
            }
            notificationService.notify(student, Notification.NotificationType.SESSION_CANCELLED,
                    "Your seat in the " + course + " class on " + WHEN.format(s.getScheduledStart()) + " was cancelled", ref);
            notificationService.notify(s.getTeacher(), Notification.NotificationType.SESSION_CANCELLED,
                    student.getName() + " left the " + course + " class on " + WHEN.format(s.getScheduledStart()), ref);
            return;
        }
        s.setStatus(ClassSession.SessionStatus.CANCELLED);
        classSessionRepository.save(s);
        String msg = "Class cancelled: " + course + " on " + WHEN.format(s.getScheduledStart());
        notify.forEach(u -> notificationService.notify(u, Notification.NotificationType.SESSION_CANCELLED, msg, ref));
    }

    /** Requests relevant to the viewer: admins see all, teachers/students see their own classes'. */
    @Transactional(readOnly = true)
    public List<SessionChangeRequestDto> mine(Long userId) {
        User user = requireUser(userId);
        List<SessionChangeRequest> list = switch (user.getRole()) {
            case ADMIN -> changeRepository.findAllByOrderByCreatedAtDesc();
            case TEACHER -> changeRepository.findBySession_Teacher_IdOrderByCreatedAtDesc(userId);
            case STUDENT -> changeRepository.findBySession_Students_IdOrderByCreatedAtDesc(userId);
            default -> List.of();
        };
        // A student who left a group class still sees their own request.
        if (user.getRole() == Role.STUDENT) {
            Set<Long> seen = list.stream().map(SessionChangeRequest::getId).collect(Collectors.toSet());
            List<SessionChangeRequest> merged = new ArrayList<>(list);
            changeRepository.findAllByOrderByCreatedAtDesc().stream()
                    .filter(r -> r.getRequestedBy().getId().equals(userId) && !seen.contains(r.getId()))
                    .forEach(merged::add);
            merged.sort(Comparator.comparing(SessionChangeRequest::getCreatedAt).reversed());
            list = merged;
        }
        return list.stream().map(r -> toDto(r, user)).toList();
    }

    @Transactional(readOnly = true)
    public List<SessionChangeRequestDto> forSession(Long userId, Long sessionId) {
        User user = requireUser(userId);
        return changeRepository.findBySessionIdOrderByCreatedAtDesc(sessionId).stream().map(r -> toDto(r, user)).toList();
    }

    private SessionChangeRequestDto toDto(SessionChangeRequest r, User viewer) {
        ClassSession s = r.getSession();
        Map<Long, String> names = new HashMap<>();
        s.getStudents().forEach(st -> names.put(st.getId(), st.getName()));
        names.put(s.getTeacher().getId(), s.getTeacher().getName());

        List<String> approvedBy = new ArrayList<>();
        if (r.isAdminApproved()) approvedBy.add("Admin");
        if (r.isTeacherApproved()) approvedBy.add(s.getTeacher().getName());
        parseIds(r.getApprovedStudentIds()).forEach(id -> approvedBy.add(names.getOrDefault(id, "Student")));

        Set<Long> awaitingIds = awaitingUserIds(r);
        List<String> awaiting = new ArrayList<>();
        if (r.getStatus() == ChangeStatus.PENDING && !r.isAdminApproved()) awaiting.add("Admin");
        awaitingIds.forEach(id -> awaiting.add(names.getOrDefault(id, "User")));

        boolean pending = r.getStatus() == ChangeStatus.PENDING;
        boolean canDecide = pending && (awaitingIds.contains(viewer.getId())
                || (viewer.getRole() == Role.ADMIN && !r.isAdminApproved()));
        boolean canWithdraw = pending && r.getRequestedBy().getId().equals(viewer.getId());

        return new SessionChangeRequestDto(r.getId(), s.getId(), s.getCourse().getId(), s.getCourse().getTitle(),
                s.getTeacher().getName(), s.getStudents().stream().map(User::getName).toList(),
                r.getType().name(), r.getStatus().name(), r.getOriginalStart(), r.getOriginalEnd(),
                r.getNewStart(), r.getNewEnd(), r.getReason(), r.getRequestedBy().getId(), r.getRequestedBy().getName(),
                r.getRequesterRole().name(), approvedBy, awaiting, canDecide, canWithdraw,
                r.getRejectedBy() != null ? r.getRejectedBy().getName() : null, r.getDecisionNote(),
                r.getCreatedAt(), r.getDecidedAt());
    }
}
