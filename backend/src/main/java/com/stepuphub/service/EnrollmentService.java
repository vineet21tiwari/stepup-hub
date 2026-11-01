package com.stepuphub.service;

import com.stepuphub.domain.*;
import com.stepuphub.dto.DecisionRequest;
import com.stepuphub.dto.EnrollmentRequestDto;
import com.stepuphub.repository.*;
import com.stepuphub.util.AppTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Student books a Slot -> EnrollmentRequest is created.
 * Flow: PENDING_TEACHER -> (teacher approves) -> PENDING_ADMIN -> (admin approves) -> APPROVED,
 * at which point a ClassSession is created/reused for that Slot and the student is attached to it.
 */
@Service
@RequiredArgsConstructor
public class EnrollmentService {

    private final UserRepository userRepository;
    private final SlotRepository slotRepository;
    private final EnrollmentRequestRepository enrollmentRequestRepository;
    private final ClassSessionRepository classSessionRepository;
    private final CourseCoordinatorRepository courseCoordinatorRepository;
    private final NotificationService notificationService;

    @Transactional
    public EnrollmentRequestDto bookSlot(Long studentId, Long slotId) {
        User student = userRepository.findById(studentId).orElseThrow(() -> new IllegalArgumentException("Student not found"));
        if (student.getRole() != Role.STUDENT) throw new IllegalArgumentException("Only students can book slots");

        Slot slot = slotRepository.findById(slotId).orElseThrow(() -> new IllegalArgumentException("Slot not found"));
        if (slot.isCancelled()) throw new IllegalArgumentException("This slot has been cancelled");
        if (slot.isFull()) throw new IllegalArgumentException("This slot is fully booked");
        if (slot.getClassesPerWeek() > 0) {
            throw new IllegalArgumentException(
                    "This course needs " + slot.getClassesPerWeek() + " classes/week — book it from the weekly availability picker.");
        }

        List<RequestStatus> activeStatuses = List.of(RequestStatus.PENDING_TEACHER, RequestStatus.PENDING_ADMIN, RequestStatus.APPROVED);
        boolean alreadyBooked = !enrollmentRequestRepository
                .findByStudentIdAndSlotCourseIdAndStatusIn(studentId, slot.getCourse().getId(), activeStatuses)
                .isEmpty();
        if (alreadyBooked) {
            throw new IllegalArgumentException("You already have an active booking for \"" + slot.getCourse().getTitle() + "\"");
        }

        LocalDate date = slot.getStartTime().atZone(AppTime.ZONE).toLocalDate();
        boolean sameDayBooked = enrollmentRequestRepository.findByStudentIdAndStatusIn(studentId, activeStatuses).stream()
                .anyMatch(r -> r.getSlot().getStartTime().atZone(AppTime.ZONE).toLocalDate().equals(date));
        if (sameDayBooked) {
            throw new IllegalArgumentException("You already have a class booked on " + date + " — only one class per day is allowed");
        }

        EnrollmentRequest req = new EnrollmentRequest();
        req.setStudent(student);
        req.setSlot(slot);
        req = enrollmentRequestRepository.save(req);

        notificationService.notify(slot.getTeacher(), Notification.NotificationType.ENROLLMENT_REQUEST_CREATED,
                student.getName() + " requested to book your slot for \"" + slot.getCourse().getTitle() + "\"",
                "ENROLLMENT_REQUEST:" + req.getId());

        return EnrollmentRequestDto.from(req);
    }

    // Books a whole weekly commitment at once: one chosen Slot "template" per weekday, expanded to
    // every future dated occurrence sharing that recurrenceGroupId + weekday, all approved/rejected
    // together later via teacherDecide/adminDecide (see batchId).
    @Transactional
    public List<EnrollmentRequestDto> bookRecurring(Long studentId, List<Long> slotIds) {
        User student = userRepository.findById(studentId).orElseThrow(() -> new IllegalArgumentException("Student not found"));
        if (student.getRole() != Role.STUDENT) throw new IllegalArgumentException("Only students can book slots");
        if (slotIds == null || slotIds.isEmpty()) throw new IllegalArgumentException("Select at least one day");

        List<Slot> chosen = slotIds.stream()
                .map(id -> slotRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Slot not found: " + id)))
                .toList();

        Slot first = chosen.get(0);
        String groupId = first.getRecurrenceGroupId();
        if (groupId == null) {
            throw new IllegalArgumentException("This isn't part of a weekly availability plan — book it directly instead");
        }
        for (Slot s : chosen) {
            if (s.isCancelled()) throw new IllegalArgumentException("One of the selected days has been cancelled");
            if (!groupId.equals(s.getRecurrenceGroupId())) {
                throw new IllegalArgumentException("Selected days must all belong to the same weekly plan");
            }
        }

        // Each weekday's window is now sliced into hourly Slots (e.g. Monday 4-5pm and 5-6pm are
        // separate rows), so a chosen day must be matched by weekday AND hour-of-day — matching by
        // weekday alone would sweep in every other hour offered that same weekday.
        Set<DayOfWeek> chosenWeekdays = chosen.stream()
                .map(s -> s.getStartTime().atZone(AppTime.ZONE).getDayOfWeek())
                .collect(Collectors.toSet());
        if (chosenWeekdays.size() != chosen.size()) {
            throw new IllegalArgumentException("Pick a different weekday for each selection");
        }
        Set<String> chosenDayHourKeys = chosen.stream().map(EnrollmentService::dayHourKey).collect(Collectors.toSet());

        int required = first.getClassesPerWeek();
        if (required > 0 && chosen.size() != required) {
            throw new IllegalArgumentException("This course needs exactly " + required + " day(s) per week — you selected " + chosen.size());
        }

        Instant now = Instant.now();
        List<Slot> toBook = slotRepository.findByRecurrenceGroupIdAndCancelledFalse(groupId).stream()
                .filter(s -> !s.getStartTime().isBefore(now))
                .filter(s -> !s.isFull())
                .filter(s -> chosenDayHourKeys.contains(dayHourKey(s)))
                .toList();
        if (toBook.isEmpty()) {
            throw new IllegalArgumentException("No upcoming occurrences left for the selected days");
        }

        List<RequestStatus> activeStatuses = List.of(RequestStatus.PENDING_TEACHER, RequestStatus.PENDING_ADMIN, RequestStatus.APPROVED);
        Set<LocalDate> studentBusyDates = enrollmentRequestRepository.findByStudentIdAndStatusIn(studentId, activeStatuses).stream()
                .map(r -> r.getSlot().getStartTime().atZone(AppTime.ZONE).toLocalDate())
                .collect(Collectors.toSet());
        for (Slot s : toBook) {
            LocalDate date = s.getStartTime().atZone(AppTime.ZONE).toLocalDate();
            if (studentBusyDates.contains(date)) {
                throw new IllegalArgumentException("You already have a class booked on " + date + " — only one class per day is allowed");
            }
        }

        String batchId = UUID.randomUUID().toString();
        List<EnrollmentRequest> created = new ArrayList<>();
        for (Slot s : toBook) {
            EnrollmentRequest req = new EnrollmentRequest();
            req.setStudent(student);
            req.setSlot(s);
            req.setBatchId(batchId);
            created.add(enrollmentRequestRepository.save(req));
        }

        notificationService.notify(first.getTeacher(), Notification.NotificationType.ENROLLMENT_REQUEST_CREATED,
                student.getName() + " requested " + chosen.size() + " weekly classes for \"" + first.getCourse().getTitle() + "\"",
                "ENROLLMENT_REQUEST:" + created.get(0).getId());

        return created.stream().map(EnrollmentRequestDto::from).toList();
    }

    // Lets a student withdraw their own booking request before it's fully approved — nothing
    // depends on a still-pending request yet (the Slot's bookedCount only increments on admin
    // approval), so it's safe to just remove it. Cancels the whole weekly batch at once if this
    // request is part of one.
    @Transactional
    public void cancelRequest(Long studentId, Long requestId) {
        EnrollmentRequest req = enrollmentRequestRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("Request not found"));
        if (!req.getStudent().getId().equals(studentId)) {
            throw new IllegalArgumentException("Not your booking request");
        }
        if (req.getStatus() != RequestStatus.PENDING_TEACHER && req.getStatus() != RequestStatus.PENDING_ADMIN) {
            throw new IllegalArgumentException("This request has already been decided — it can no longer be cancelled");
        }

        List<EnrollmentRequest> batch = req.getBatchId() != null
                ? enrollmentRequestRepository.findByBatchId(req.getBatchId()).stream()
                    .filter(r -> r.getStatus() == req.getStatus()).toList()
                : List.of(req);
        enrollmentRequestRepository.deleteAll(batch);
    }

    @Transactional
    public EnrollmentRequestDto teacherDecide(Long teacherId, Long requestId, DecisionRequest decision) {
        EnrollmentRequest req = enrollmentRequestRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("Request not found"));
        if (!req.getSlot().getTeacher().getId().equals(teacherId)) {
            throw new IllegalArgumentException("This request is not for one of your slots");
        }
        if (req.getStatus() != RequestStatus.PENDING_TEACHER) {
            throw new IllegalArgumentException("Request already handled (status: " + req.getStatus() + ")");
        }

        List<EnrollmentRequest> batch = req.getBatchId() != null
                ? enrollmentRequestRepository.findByBatchId(req.getBatchId()).stream()
                    .filter(r -> r.getStatus() == RequestStatus.PENDING_TEACHER).toList()
                : List.of(req);
        String courseTitle = req.getSlot().getCourse().getTitle();
        String suffix = batch.size() > 1 ? " (" + batch.size() + " weekly classes)" : "";

        batch.forEach(r -> r.setTeacherNote(decision.getNote()));
        if (decision.isApprove()) {
            batch.forEach(r -> r.setStatus(RequestStatus.PENDING_ADMIN));
            enrollmentRequestRepository.saveAll(batch);
            userRepository.findByRole(Role.ADMIN).forEach(admin ->
                    notificationService.notify(admin, Notification.NotificationType.ENROLLMENT_APPROVED_BY_TEACHER,
                            "Teacher approved " + req.getStudent().getName() + "'s booking for \"" + courseTitle + "\"" + suffix + " — needs your approval",
                            "ENROLLMENT_REQUEST:" + req.getId()));
            // Approval is a two-step (teacher, then admin) process internally, but the student just
            // sees one pending request — don't name either reviewer in what they're shown.
            notificationService.notify(req.getStudent(), Notification.NotificationType.ENROLLMENT_APPROVED_BY_TEACHER,
                    "Your booking request for \"" + courseTitle + "\"" + suffix + " is being processed.",
                    "ENROLLMENT_REQUEST:" + req.getId());
        } else {
            batch.forEach(r -> r.setStatus(RequestStatus.REJECTED_BY_TEACHER));
            enrollmentRequestRepository.saveAll(batch);
            notificationService.notify(req.getStudent(), Notification.NotificationType.ENROLLMENT_REJECTED_BY_TEACHER,
                    "Your booking request for \"" + courseTitle + "\"" + suffix + " was declined.",
                    "ENROLLMENT_REQUEST:" + req.getId());
        }
        return EnrollmentRequestDto.from(req);
    }

    @Transactional
    public EnrollmentRequestDto adminDecide(Long adminId, Long requestId, DecisionRequest decision) {
        User admin = userRepository.findById(adminId).orElseThrow(() -> new IllegalArgumentException("Admin not found"));
        if (admin.getRole() != Role.ADMIN) throw new IllegalArgumentException("Only admins can approve enrollment");

        EnrollmentRequest req = enrollmentRequestRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("Request not found"));
        if (req.getStatus() != RequestStatus.PENDING_ADMIN) {
            throw new IllegalArgumentException("Request is not awaiting admin approval (status: " + req.getStatus() + ")");
        }

        req.setAdminNote(decision.getNote());

        List<EnrollmentRequest> batch = req.getBatchId() != null
                ? enrollmentRequestRepository.findByBatchId(req.getBatchId()).stream()
                    .filter(r -> r.getStatus() == RequestStatus.PENDING_ADMIN).toList()
                : List.of(req);
        String courseTitle = req.getSlot().getCourse().getTitle();
        String suffix = batch.size() > 1 ? " (" + batch.size() + " weekly classes)" : "";

        if (decision.isApprove()) {
            ClassSession firstSession = null;
            for (EnrollmentRequest r : batch) {
                r.setAdminNote(decision.getNote());
                Slot slot = r.getSlot();
                if (slot.isFull()) {
                    throw new IllegalArgumentException("Slot filled up while this request was pending: " + slot.getStartTime());
                }
                r.setStatus(RequestStatus.APPROVED);
                slot.setBookedCount(slot.getBookedCount() + 1);
                slotRepository.save(slot);

                ClassSession session = getOrCreateSessionForSlot(slot);
                session.getStudents().add(r.getStudent());
                classSessionRepository.save(session);
                if (firstSession == null) firstSession = session;
            }
            enrollmentRequestRepository.saveAll(batch);

            String msg = "Class \"" + courseTitle + "\" is scheduled" + suffix;
            notificationService.notify(req.getStudent(), Notification.NotificationType.ENROLLMENT_APPROVED, msg, "SESSION:" + firstSession.getId());
            notificationService.notify(req.getSlot().getTeacher(), Notification.NotificationType.SESSION_SCHEDULED,
                    req.getStudent().getName() + " is confirmed for \"" + courseTitle + "\"" + suffix,
                    "SESSION:" + firstSession.getId());
            Long scheduledSessionId = firstSession.getId();
            courseCoordinatorRepository.findByCourseId(firstSession.getCourse().getId())
                    .forEach(cc -> notificationService.notify(cc.getCoordinator(), Notification.NotificationType.SESSION_SCHEDULED, msg, "SESSION:" + scheduledSessionId));
        } else {
            batch.forEach(r -> { r.setAdminNote(decision.getNote()); r.setStatus(RequestStatus.REJECTED_BY_ADMIN); });
            enrollmentRequestRepository.saveAll(batch);
            notificationService.notify(req.getStudent(), Notification.NotificationType.ENROLLMENT_REJECTED,
                    "Your booking request for \"" + courseTitle + "\"" + suffix + " was declined.",
                    "ENROLLMENT_REQUEST:" + req.getId());
        }
        return EnrollmentRequestDto.from(req);
    }

    // Identifies "the same recurring time slot" across weeks: same weekday + same time-of-day.
    private static String dayHourKey(Slot s) {
        var zoned = s.getStartTime().atZone(AppTime.ZONE);
        return zoned.getDayOfWeek() + "@" + zoned.toLocalTime();
    }

    private ClassSession getOrCreateSessionForSlot(Slot slot) {
        // One ClassSession per Slot in Phase 1 (a slot represents one scheduled class occurrence).
        Optional<ClassSession> existing = classSessionRepository.findAll().stream()
                .filter(s -> slot.equals(s.getSlot()))
                .findFirst();
        if (existing.isPresent()) return existing.get();

        ClassSession session = new ClassSession();
        session.setCourse(slot.getCourse());
        session.setTeacher(slot.getTeacher());
        session.setSlot(slot);
        session.setScheduledStart(slot.getStartTime());
        session.setScheduledEnd(slot.getEndTime());
        return classSessionRepository.save(session);
    }

    @Transactional(readOnly = true)
    public List<EnrollmentRequestDto> requestsForStudent(Long studentId) {
        return enrollmentRequestRepository.findByStudentId(studentId).stream().map(EnrollmentRequestDto::from).toList();
    }

    @Transactional(readOnly = true)
    public List<EnrollmentRequestDto> pendingForTeacher(Long teacherId) {
        return enrollmentRequestRepository.findBySlotTeacherIdAndStatus(teacherId, RequestStatus.PENDING_TEACHER)
                .stream().map(EnrollmentRequestDto::from).toList();
    }

    @Transactional(readOnly = true)
    public List<EnrollmentRequestDto> pendingForAdmin() {
        return enrollmentRequestRepository.findByStatus(RequestStatus.PENDING_ADMIN)
                .stream().map(EnrollmentRequestDto::from).toList();
    }
}
