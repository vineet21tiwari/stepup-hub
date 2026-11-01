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
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
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

        if (slotRepository.findFirstByTeacherIdAndCourseIdAndCancelledFalse(teacherId, req.getCourseId()).isPresent()) {
            throw new IllegalArgumentException("You already have an active slot for this course. Edit it instead of creating a new one.");
        }

        Slot slot = new Slot();
        slot.setTeacher(teacher);
        slot.setCourse(course);
        slot.setStartTime(req.getStartTime());
        slot.setEndTime(req.getEndTime());
        slot.setCapacity(req.getCapacity() == null ? 1 : req.getCapacity());
        return SlotDto.from(slotRepository.save(slot));
    }

    // Edits the teacher's single active slot for a course (time and/or capacity) instead of
    // replacing it with a new row, since only one active slot per teacher/course is allowed.
    @Transactional
    public SlotDto updateSlot(Long teacherId, Long slotId, SlotRequest req) {
        Slot slot = slotRepository.findById(slotId).orElseThrow(() -> new IllegalArgumentException("Slot not found"));
        if (!slot.getTeacher().getId().equals(teacherId)) {
            throw new IllegalArgumentException("Not your slot");
        }
        if (slot.isCancelled()) {
            throw new IllegalArgumentException("Cannot edit a cancelled slot");
        }
        if (!req.getEndTime().isAfter(req.getStartTime())) {
            throw new IllegalArgumentException("Slot end time must be after start time");
        }
        int capacity = req.getCapacity() == null ? slot.getCapacity() : req.getCapacity();
        if (capacity < slot.getBookedCount()) {
            throw new IllegalArgumentException("Capacity cannot be lower than the current booked count (" + slot.getBookedCount() + ")");
        }

        slot.setStartTime(req.getStartTime());
        slot.setEndTime(req.getEndTime());
        slot.setCapacity(capacity);
        return SlotDto.from(slotRepository.save(slot));
    }

    // Generates one Slot per hour within each matching weekday's time window, from req.startDate
    // through req.repeatUntil, all sharing one recurrenceGroupId (see cancelSlotSeries for the
    // matching bulk-cancel). Slicing into hourly chunks (instead of one block spanning the whole
    // window) is what lets a student pick a specific hour to book from the calendar.
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
        if (slotRepository.findFirstByTeacherIdAndCourseIdAndCancelledFalse(teacherId, req.getCourseId()).isPresent()) {
            throw new IllegalArgumentException("You already have an active slot for this course. Cancel it before creating a recurring series.");
        }

        Set<DayOfWeek> seenDays = new HashSet<>();
        for (RecurringSlotRequest.DayWindow w : req.getDayWindows()) {
            if (!w.getEndTime().isAfter(w.getStartTime())) {
                throw new IllegalArgumentException("End time must be after start time for " + w.getDayOfWeek());
            }
            if (!seenDays.add(w.getDayOfWeek())) {
                throw new IllegalArgumentException("Duplicate time window for " + w.getDayOfWeek());
            }
        }
        int classesPerWeek = req.getClassesPerWeek();
        if (classesPerWeek < 1 || classesPerWeek > req.getDayWindows().size()) {
            throw new IllegalArgumentException("classesPerWeek must be between 1 and the number of days offered (" + req.getDayWindows().size() + ")");
        }

        int capacity = req.getCapacity() == null ? 1 : req.getCapacity();
        SessionType sessionType = req.getSessionType() == null ? SessionType.ONE_ON_ONE : req.getSessionType();
        String groupId = UUID.randomUUID().toString();

        List<Slot> created = new ArrayList<>();
        for (LocalDate date = req.getStartDate(); !date.isAfter(req.getRepeatUntil()); date = date.plusDays(1)) {
            LocalDate d = date;
            RecurringSlotRequest.DayWindow window = req.getDayWindows().stream()
                    .filter(w -> w.getDayOfWeek() == d.getDayOfWeek())
                    .findFirst().orElse(null);
            if (window == null) continue;

            for (LocalTime hourStart = window.getStartTime();
                 hourStart.isBefore(window.getEndTime());
                 hourStart = hourStart.plusHours(1)) {
                LocalTime hourEnd = hourStart.plusHours(1);
                if (hourEnd.isAfter(window.getEndTime()) || hourEnd.equals(LocalTime.MIDNIGHT)) {
                    hourEnd = window.getEndTime();
                }

                Instant occStart = date.atTime(hourStart).atZone(AppTime.ZONE).toInstant();
                Instant occEnd = date.atTime(hourEnd).atZone(AppTime.ZONE).toInstant();
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
        }
        if (created.isEmpty()) {
            throw new IllegalArgumentException("No occurrences matched the given days of week within the date range");
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

    // Bulk-cancels every still-active slot generated from one createRecurringSlots call.
    @Transactional
    public void cancelSlotSeries(Long teacherId, String recurrenceGroupId) {
        List<Slot> slots = slotRepository.findByRecurrenceGroupIdAndCancelledFalse(recurrenceGroupId);
        if (slots.isEmpty()) {
            throw new IllegalArgumentException("No active slots found for this series");
        }
        for (Slot slot : slots) {
            if (!slot.getTeacher().getId().equals(teacherId)) {
                throw new IllegalArgumentException("Not your slot series");
            }
        }
        slots.forEach(s -> s.setCancelled(true));
        slotRepository.saveAll(slots);
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

    @Transactional
    public void cancelSlot(Long teacherId, Long slotId) {
        Slot slot = slotRepository.findById(slotId).orElseThrow(() -> new IllegalArgumentException("Slot not found"));
        if (!slot.getTeacher().getId().equals(teacherId)) {
            throw new IllegalArgumentException("Not your slot");
        }
        slot.setCancelled(true);
        slotRepository.save(slot);
    }

    @Transactional(readOnly = true)
    public List<UserSummaryDto> approvedTeachers() {
        return userRepository.findByRoleAndApprovedAndActive(Role.TEACHER, true, true).stream().map(UserSummaryDto::from).toList();
    }
}
