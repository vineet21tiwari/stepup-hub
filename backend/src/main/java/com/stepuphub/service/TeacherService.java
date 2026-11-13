package com.stepuphub.service;

import com.stepuphub.domain.*;
import com.stepuphub.dto.*;
import com.stepuphub.repository.*;
import com.stepuphub.util.AppTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Handles: teacher -> course applications (admin approves), and teacher availability slots.
 */
@Service
@RequiredArgsConstructor
public class TeacherService {

    private final UserRepository userRepository;
    private final CourseRepository courseRepository;
    private final TeacherCourseEnrollmentRepository tceRepository;
    private final SlotRepository slotRepository;
    private final ClassSessionRepository classSessionRepository;
    private final EnrollmentRequestRepository enrollmentRequestRepository;
    private final NotificationService notificationService;
    private final FileStorageService fileStorageService;

    private User requireRole(Long userId, Role role) {
        User u = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));
        if (u.getRole() != role) throw new IllegalArgumentException("Requires role " + role);
        return u;
    }

    // ---- Teacher applies to teach a course ----
    @Transactional
    public TeacherApplicationDto applyToCourse(Long teacherId, Long courseId, MultipartFile introVideo) {
        User teacher = requireRole(teacherId, Role.TEACHER);
        Course course = courseRepository.findById(courseId).orElseThrow(() -> new IllegalArgumentException("Course not found"));

        tceRepository.findByTeacherIdAndCourseId(teacherId, courseId).ifPresent(existing -> {
            throw new IllegalArgumentException("You already applied to this course (status: " + existing.getStatus() + ")");
        });






        TeacherCourseEnrollment e = new TeacherCourseEnrollment();
        e.setTeacher(teacher);
        e.setCourse(course);
        if (introVideo != null && !introVideo.isEmpty()) {
            e.setIntroVideoUrl(fileStorageService.store("intro-videos", introVideo));
        }
        final TeacherCourseEnrollment saved = tceRepository.save(e);

        userRepository.findByRole(Role.ADMIN).forEach(admin ->
                notificationService.notify(admin, Notification.NotificationType.TEACHER_APPLICATION_SUBMITTED,
                        teacher.getName() + " applied to teach \"" + course.getTitle() + "\"", "TEACHER_APPLICATION:" + saved.getId()));

        return TeacherApplicationDto.from(saved);
    }

    // Lets a teacher add/replace the short intro video for one of their (own) course applications,
    // e.g. if they skipped it when first applying. Students browsing the course use this to help
    // decide which teacher to book.
    @Transactional
    public TeacherApplicationDto uploadApplicationVideo(Long teacherId, Long applicationId, MultipartFile introVideo) {
        if (introVideo == null || introVideo.isEmpty()) {
            throw new IllegalArgumentException("A video file is required");
        }
        TeacherCourseEnrollment e = tceRepository.findById(applicationId)
                .orElseThrow(() -> new IllegalArgumentException("Application not found"));
        if (!e.getTeacher().getId().equals(teacherId)) {
            throw new IllegalArgumentException("Not your application");
        }
        e.setIntroVideoUrl(fileStorageService.store("intro-videos", introVideo));
        return TeacherApplicationDto.from(tceRepository.save(e));
    }

    @Transactional(readOnly = true)
    public List<TeacherApplicationDto> pendingApplications() {
        return tceRepository.findByStatus(ApprovalStatus.PENDING).stream().map(TeacherApplicationDto::from).toList();
    }

    @Transactional(readOnly = true)
    public List<TeacherApplicationDto> applicationsForTeacher(Long teacherId) {
        return tceRepository.findByTeacherId(teacherId).stream().map(TeacherApplicationDto::from).toList();
    }

    // A teacher can withdraw their own application while it's still awaiting admin review —
    // nothing depends on a PENDING application yet (no slots/sessions reference it), so it's
    // safe to just remove it rather than tracking a "cancelled" status.
    @Transactional
    public void cancelApplication(Long teacherId, Long applicationId) {
        TeacherCourseEnrollment e = tceRepository.findById(applicationId)
                .orElseThrow(() -> new IllegalArgumentException("Application not found"));
        if (!e.getTeacher().getId().equals(teacherId)) {
            throw new IllegalArgumentException("Not your application");
        }
        if (e.getStatus() != ApprovalStatus.PENDING) {
            throw new IllegalArgumentException("This application has already been " + e.getStatus().name().toLowerCase());
        }
        tceRepository.delete(e);
    }

    @Transactional
    public TeacherApplicationDto decideApplication(Long adminId, Long applicationId, boolean approve) {
        User admin = requireRole(adminId, Role.ADMIN);
        TeacherCourseEnrollment e = tceRepository.findById(applicationId)
                .orElseThrow(() -> new IllegalArgumentException("Application not found"));
        e.setStatus(approve ? ApprovalStatus.APPROVED : ApprovalStatus.REJECTED);
        e.setReviewedBy(admin);
        e = tceRepository.save(e);

        // Approving a course application also marks the teacher's overall account approved,
        // so they can be discovered/booked platform-wide.
        User teacher = e.getTeacher();
        if (approve && !teacher.isApproved()) {
            teacher.setApproved(true);
            userRepository.save(teacher);
        }

        notificationService.notify(teacher,
                approve ? Notification.NotificationType.TEACHER_APPLICATION_APPROVED : Notification.NotificationType.TEACHER_APPLICATION_REJECTED,
                "Your application to teach \"" + e.getCourse().getTitle() + "\" was " + (approve ? "approved" : "rejected"),
                "TEACHER_APPLICATION:" + e.getId());

        return TeacherApplicationDto.from(e);
    }

    // ---- Slots ----
    @Transactional
    public SlotDto createSlot(Long teacherId, SlotRequest req) {
        User teacher = requireRole(teacherId, Role.TEACHER);
        Course course = courseRepository.findById(req.getCourseId())
                .orElseThrow(() -> new IllegalArgumentException("Course not found"));

        tceRepository.findByTeacherIdAndCourseId(teacherId, req.getCourseId())
                .filter(e -> e.getStatus() == ApprovalStatus.APPROVED)
                .orElseThrow(() -> new IllegalArgumentException("You must be an approved teacher for this course before adding slots"));

        if (!req.getEndTime().isAfter(req.getStartTime())) {
            throw new IllegalArgumentException("Slot end time must be after start time");
        }

        boolean clash = slotRepository.findByTeacherIdAndCancelledFalse(teacherId).stream()
                .anyMatch(s -> s.getStartTime().isBefore(req.getEndTime()) && req.getStartTime().isBefore(s.getEndTime()));
        if (clash) {
            throw new IllegalArgumentException("You already have a slot overlapping this time");
        }

        Slot slot = new Slot();
        slot.setTeacher(teacher);
        slot.setCourse(course);
        slot.setStartTime(req.getStartTime());
        slot.setEndTime(req.getEndTime());
        slot.setCapacity(req.getCapacity() == null ? 1 : req.getCapacity());
        return SlotDto.from(slotRepository.save(slot));
    }

    // A slot counts as "taken" once a student has an approved booking OR a still-pending request on it —
    // the teacher can no longer move or remove it (only an admin can, see adminCancelSlotSeries).
    private boolean isTaken(Slot slot) {
        return slot.getBookedCount() > 0 || !enrollmentRequestRepository
                .findBySlotIdAndStatusIn(slot.getId(), List.of(RequestStatus.PENDING_TEACHER, RequestStatus.PENDING_ADMIN))
                .isEmpty();
    }

    private static final DateTimeFormatter WHEN = DateTimeFormatter.ofPattern("EEE, MMM d h:mm a").withZone(AppTime.ZONE);
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("h:mm a").withZone(AppTime.ZONE);

    // Edits one of the teacher's slots (time and/or capacity). Only allowed while nobody has booked it;
    // students with a pending request on it are notified of the new time.
    @Transactional
    public SlotDto updateSlot(Long teacherId, Long slotId, SlotRequest req) {
        Slot slot = slotRepository.findById(slotId).orElseThrow(() -> new IllegalArgumentException("Slot not found"));
        if (!slot.getTeacher().getId().equals(teacherId)) {
            throw new IllegalArgumentException("Not your slot");
        }
        if (slot.isCancelled()) {
            throw new IllegalArgumentException("Cannot edit a cancelled slot");
        }
        if (slot.getBookedCount() > 0) {
            throw new IllegalArgumentException("This slot is already booked by a student and can't be changed. "
                    + "Raise a change request from the class instead.");
        }
        if (!req.getEndTime().isAfter(req.getStartTime())) {
            throw new IllegalArgumentException("Slot end time must be after start time");
        }
        int capacity = req.getCapacity() == null ? slot.getCapacity() : req.getCapacity();
        boolean clash = slotRepository.findByTeacherIdAndCancelledFalse(teacherId).stream()
                .filter(s -> !s.getId().equals(slotId))
                .anyMatch(s -> s.getStartTime().isBefore(req.getEndTime()) && req.getStartTime().isBefore(s.getEndTime()));
        if (clash) {
            throw new IllegalArgumentException("You already have another slot overlapping this time");
        }

        boolean timeChanged = !slot.getStartTime().equals(req.getStartTime()) || !slot.getEndTime().equals(req.getEndTime());
        slot.setStartTime(req.getStartTime());
        slot.setEndTime(req.getEndTime());
        slot.setCapacity(capacity);
        Slot saved = slotRepository.save(slot);

        if (timeChanged) {
            String when = WHEN.format(saved.getStartTime()) + " - " + TIME.format(saved.getEndTime());
            enrollmentRequestRepository
                    .findBySlotIdAndStatusIn(saved.getId(), List.of(RequestStatus.PENDING_TEACHER, RequestStatus.PENDING_ADMIN))
                    .forEach(r -> notificationService.notify(r.getStudent(), Notification.NotificationType.GENERAL,
                            saved.getTeacher().getName() + " changed the time of the slot you requested for \""
                                    + saved.getCourse().getTitle() + "\" to " + when,
                            "ENROLLMENT_REQUEST:" + r.getId()));
        }
        return SlotDto.from(saved);
    }

    // Generates one Slot per hour within each matching weekday's time window(s), from req.startDate
    // through req.repeatUntil, all sharing one recurrenceGroupId. A weekday may carry several windows
    // (e.g. Monday 9-10 AM and 3-4 PM) as long as they don't overlap. Hours the teacher already offers
    // (in any course) are skipped rather than doubled up.
    @Transactional
    public List<SlotDto> createRecurringSlots(Long teacherId, RecurringSlotRequest req) {
        User teacher = requireRole(teacherId, Role.TEACHER);
        Course course = courseRepository.findById(req.getCourseId())
                .orElseThrow(() -> new IllegalArgumentException("Course not found"));

        tceRepository.findByTeacherIdAndCourseId(teacherId, req.getCourseId())
                .filter(e -> e.getStatus() == ApprovalStatus.APPROVED)
                .orElseThrow(() -> new IllegalArgumentException("You must be an approved teacher for this course before adding slots"));

        if (req.getRepeatUntil().isBefore(req.getStartDate())) {
            throw new IllegalArgumentException("repeatUntil must be on or after the start date");
        }

        Map<DayOfWeek, List<RecurringSlotRequest.DayWindow>> byDay = new EnumMap<>(DayOfWeek.class);
        for (RecurringSlotRequest.DayWindow w : req.getDayWindows()) {
            if (!w.getEndTime().isAfter(w.getStartTime())) {
                throw new IllegalArgumentException("End time must be after start time for " + w.getDayOfWeek());
            }
            byDay.computeIfAbsent(w.getDayOfWeek(), k -> new ArrayList<>()).add(w);
        }
        for (Map.Entry<DayOfWeek, List<RecurringSlotRequest.DayWindow>> e : byDay.entrySet()) {
            e.getValue().sort(Comparator.comparing(RecurringSlotRequest.DayWindow::getStartTime));
            List<RecurringSlotRequest.DayWindow> ws = e.getValue();
            for (int i = 1; i < ws.size(); i++) {
                if (ws.get(i).getStartTime().isBefore(ws.get(i - 1).getEndTime())) {
                    throw new IllegalArgumentException("Time slots overlap on " + e.getKey());
                }
            }
        }
        int classesPerWeek = req.getClassesPerWeek();
        if (classesPerWeek < 1 || classesPerWeek > byDay.size()) {
            throw new IllegalArgumentException("classesPerWeek must be between 1 and the number of days offered (" + byDay.size() + ")");
        }

        int capacity = req.getCapacity() == null ? 1 : req.getCapacity();
        SessionType sessionType = req.getSessionType() == null ? SessionType.ONE_ON_ONE : req.getSessionType();
        String groupId = UUID.randomUUID().toString();

        List<Slot> existing = slotRepository.findByTeacherIdAndCancelledFalse(teacherId);

        List<Slot> created = new ArrayList<>();
        for (LocalDate date = req.getStartDate(); !date.isAfter(req.getRepeatUntil()); date = date.plusDays(1)) {
            List<RecurringSlotRequest.DayWindow> windows = byDay.get(date.getDayOfWeek());
            if (windows == null) continue;

            for (RecurringSlotRequest.DayWindow window : windows) {
                LocalTime hourStart = window.getStartTime();
                while (hourStart.isBefore(window.getEndTime())) {
                    LocalTime hourEnd = hourStart.plusHours(1);
                    boolean last = hourEnd.isAfter(window.getEndTime()) || !hourEnd.isAfter(hourStart);
                    if (last) hourEnd = window.getEndTime();

                    Instant occStart = date.atTime(hourStart).atZone(AppTime.ZONE).toInstant();
                    Instant occEnd = date.atTime(hourEnd).atZone(AppTime.ZONE).toInstant();
                    boolean clash = existing.stream().anyMatch(s ->
                            s.getStartTime().isBefore(occEnd) && occStart.isBefore(s.getEndTime()));
                    if (!clash) {
                        Slot slot = new Slot();
                        slot.setTeacher(teacher);
                        slot.setCourse(course);
                        slot.setStartTime(occStart);
                        slot.setEndTime(occEnd);
                        slot.setCapacity(capacity);
                        slot.setSessionType(sessionType);
                        slot.setClassesPerWeek(classesPerWeek);
                        slot.setRecurrenceGroupId(groupId);
                        created.add(slotRepository.save(slot));
                    }
                    if (last || hourEnd.equals(window.getEndTime())) break;
                    hourStart = hourEnd;
                }
            }
        }
        if (created.isEmpty()) {
            throw new IllegalArgumentException("No new slots were created — the chosen days/times don't fall in the date range or overlap your existing slots");
        }
        return created.stream().map(SlotDto::from).toList();
    }

    // A teacher's busy/blocked windows for one calendar day, across ALL of their courses —
    // used so a student browsing availability sees when a teacher is genuinely unavailable.
    @Transactional(readOnly = true)
    public List<BusyRangeDto> busyRanges(Long teacherId, LocalDate date) {
        Instant dayStart = date.atStartOfDay(AppTime.ZONE).toInstant();
        Instant dayEnd = date.plusDays(1).atStartOfDay(AppTime.ZONE).toInstant();
        return classSessionRepository
                .findByTeacherIdAndStatusNotAndScheduledStartBetween(teacherId, ClassSession.SessionStatus.CANCELLED, dayStart, dayEnd)
                .stream()
                .map(s -> new BusyRangeDto(s.getScheduledStart(), s.getScheduledEnd()))
                .toList();
    }

    // Teacher removes the EMPTY slots of a series. Slots a student has booked or requested stay put —
    // only an admin can cancel those (adminCancelSlotSeries).
    @Transactional
    public SeriesCancelResultDto cancelSlotSeries(Long teacherId, String recurrenceGroupId) {
        List<Slot> slots = slotRepository.findByRecurrenceGroupIdAndCancelledFalse(recurrenceGroupId);
        if (slots.isEmpty()) {
            throw new IllegalArgumentException("No active slots found for this series");
        }
        for (Slot slot : slots) {
            if (!slot.getTeacher().getId().equals(teacherId)) {
                throw new IllegalArgumentException("Not your slot series");
            }
        }
        List<Slot> empty = slots.stream().filter(s -> !isTaken(s)).toList();
        int kept = slots.size() - empty.size();
        if (empty.isEmpty()) {
            throw new IllegalArgumentException("Every slot in this series is booked or requested by a student — only an admin can cancel booked slots");
        }
        empty.forEach(s -> s.setCancelled(true));
        slotRepository.saveAll(empty);
        return new SeriesCancelResultDto(empty.size(), kept, 0);
    }

    // Admin cancels a whole series, booked slots included: pending requests are declined, upcoming
    // scheduled classes are cancelled, and every affected student plus the teacher is notified.
    @Transactional
    public SeriesCancelResultDto adminCancelSlotSeries(Long adminId, String recurrenceGroupId) {
        requireRole(adminId, Role.ADMIN);
        List<Slot> slots = slotRepository.findByRecurrenceGroupIdAndCancelledFalse(recurrenceGroupId);
        if (slots.isEmpty()) {
            throw new IllegalArgumentException("No active slots found for this series");
        }
        int booked = 0;
        Map<Long, User> affectedStudents = new LinkedHashMap<>();
        Instant now = Instant.now();
        for (Slot slot : slots) {
            if (isTaken(slot)) booked++;
            slot.setCancelled(true);
            List<EnrollmentRequest> pending = enrollmentRequestRepository.findBySlotIdAndStatusIn(slot.getId(),
                    List.of(RequestStatus.PENDING_TEACHER, RequestStatus.PENDING_ADMIN));
            for (EnrollmentRequest r : pending) {
                r.setStatus(RequestStatus.REJECTED_BY_ADMIN);
                r.setAdminNote("Slot series cancelled by admin");
                r.setDecidedAt(now);
                affectedStudents.put(r.getStudent().getId(), r.getStudent());
            }
            enrollmentRequestRepository.saveAll(pending);
            for (ClassSession cs : classSessionRepository.findBySlotId(slot.getId())) {
                if (cs.getStatus() == ClassSession.SessionStatus.SCHEDULED && cs.getScheduledStart().isAfter(now)) {
                    cs.setStatus(ClassSession.SessionStatus.CANCELLED);
                    cs.getStudents().forEach(st -> affectedStudents.put(st.getId(), st));
                    classSessionRepository.save(cs);
                }
            }
        }
        slotRepository.saveAll(slots);

        Slot first = slots.get(0);
        String msg = "Admin cancelled the class series for \"" + first.getCourse().getTitle() + "\" with "
                + first.getTeacher().getName() + ". Upcoming classes in this series won't take place.";
        affectedStudents.values().forEach(st ->
                notificationService.notify(st, Notification.NotificationType.SESSION_CANCELLED, msg, null));
        notificationService.notify(first.getTeacher(), Notification.NotificationType.SESSION_CANCELLED,
                "Admin cancelled your slot series for \"" + first.getCourse().getTitle() + "\" (" + slots.size() + " slots)", null);
        return new SeriesCancelResultDto(slots.size(), 0, booked);
    }

    // Admin overview: every active slot series, grouped, with how many of its slots are booked.
    @Transactional(readOnly = true)
    public List<SlotSeriesDto> allActiveSeries() {
        Map<String, List<Slot>> groups = new LinkedHashMap<>();
        slotRepository.findByCancelledFalseAndRecurrenceGroupIdIsNotNull()
                .forEach(s -> groups.computeIfAbsent(s.getRecurrenceGroupId(), k -> new ArrayList<>()).add(s));
        List<SlotSeriesDto> out = new ArrayList<>();
        groups.forEach((gid, list) -> {
            list.sort(Comparator.comparing(Slot::getStartTime));
            Slot f = list.get(0);
            int booked = (int) list.stream().filter(s -> s.getBookedCount() > 0).count();
            out.add(new SlotSeriesDto(gid, f.getTeacher().getId(), f.getTeacher().getName(),
                    f.getCourse().getId(), f.getCourse().getTitle(), f.getSessionType().name(),
                    list.size(), booked, f.getStartTime(), list.get(list.size() - 1).getStartTime()));
        });
        out.sort(Comparator.comparing(SlotSeriesDto::firstStart));
        return out;
    }

    @Transactional(readOnly = true)
    public List<SlotDto> slotsForTeacherAndCourse(Long teacherId, Long courseId) {
        return slotRepository.findByTeacherIdAndCourseIdAndCancelledFalse(teacherId, courseId)
                .stream().map(SlotDto::from).toList();
    }

    @Transactional(readOnly = true)
    public List<SlotDto> slotsForTeacher(Long teacherId) {
        return slotRepository.findByTeacherIdAndCancelledFalse(teacherId).stream().map(SlotDto::from).toList();
    }

    // Teacher removes one slot — only while it's empty (no booking and no pending request).
    @Transactional
    public void cancelSlot(Long teacherId, Long slotId) {
        Slot slot = slotRepository.findById(slotId).orElseThrow(() -> new IllegalArgumentException("Slot not found"));
        if (!slot.getTeacher().getId().equals(teacherId)) {
            throw new IllegalArgumentException("Not your slot");
        }
        if (isTaken(slot)) {
            throw new IllegalArgumentException("A student has booked or requested this slot — it can't be removed. Contact admin if it must be cancelled.");
        }
        slot.setCancelled(true);
        slotRepository.save(slot);
    }

    @Transactional(readOnly = true)
    public List<UserSummaryDto> approvedTeachers() {
        return userRepository.findByRoleAndApprovedAndActive(Role.TEACHER, true, true).stream().map(UserSummaryDto::from).toList();
    }
}
