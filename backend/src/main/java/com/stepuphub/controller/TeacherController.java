package com.stepuphub.controller;

import com.stepuphub.dto.*;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.TeacherService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/teachers")
@RequiredArgsConstructor
public class TeacherController {

    private final TeacherService teacherService;

    // Any approved teacher, platform-wide (student browsing)
    @GetMapping
    public List<UserSummaryDto> approvedTeachers() {
        return teacherService.approvedTeachers();
    }

    // ---- Teacher applies to teach a course ----
    // "video" is optional: a short intro clip students can watch when picking a teacher for this course.
    @PostMapping("/applications/{courseId}")
    public TeacherApplicationDto apply(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long courseId,
                                        @RequestParam(value = "video", required = false) MultipartFile video) {
        return teacherService.applyToCourse(principal.getId(), courseId, video);
    }

    // Add/replace the intro video for an existing application (e.g. if skipped at apply time).
    @PostMapping("/applications/{applicationId}/video")
    public TeacherApplicationDto uploadApplicationVideo(@AuthenticationPrincipal AppUserPrincipal principal,
                                                          @PathVariable Long applicationId,
                                                          @RequestParam("video") MultipartFile video) {
        return teacherService.uploadApplicationVideo(principal.getId(), applicationId, video);
    }

    @GetMapping("/applications/mine")
    public List<TeacherApplicationDto> myApplications(@AuthenticationPrincipal AppUserPrincipal principal) {
        return teacherService.applicationsForTeacher(principal.getId());
    }

    // Admin-facing: every course application (any status) for an arbitrary teacher, e.g. for a user-management screen.
    @GetMapping("/{teacherId}/applications")
    public List<TeacherApplicationDto> applicationsForTeacher(@PathVariable Long teacherId) {
        return teacherService.applicationsForTeacher(teacherId);
    }

    @GetMapping("/applications/pending")
    public List<TeacherApplicationDto> pendingApplications() {
        return teacherService.pendingApplications();
    }

    // Lets a teacher withdraw their own application while it's still pending admin review.
    @DeleteMapping("/applications/{applicationId}")
    public void cancelApplication(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long applicationId) {
        teacherService.cancelApplication(principal.getId(), applicationId);
    }

    @PostMapping("/applications/{applicationId}/decide")
    public TeacherApplicationDto decideApplication(@AuthenticationPrincipal AppUserPrincipal principal,
                                                     @PathVariable Long applicationId,
                                                     @RequestBody DecisionRequest decision) {
        return teacherService.decideApplication(principal.getId(), applicationId, decision.isApprove());
    }

    // ---- Slots ----
    @PostMapping("/slots")
    public SlotDto createSlot(@AuthenticationPrincipal AppUserPrincipal principal, @Valid @RequestBody SlotRequest req) {
        return teacherService.createSlot(principal.getId(), req);
    }

    // Edits the teacher's single active slot for a course (only one active slot per teacher/course is allowed).
    @PutMapping("/slots/{slotId}")
    public SlotDto updateSlot(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long slotId,
                               @Valid @RequestBody SlotRequest req) {
        return teacherService.updateSlot(principal.getId(), slotId, req);
    }

    // Weekly-recurring availability: generates one Slot per matching weekday, all tagged with
    // the same recurrenceGroupId (returned on each SlotDto) for later bulk cancellation.
    @PostMapping("/slots/recurring")
    public List<SlotDto> createRecurringSlots(@AuthenticationPrincipal AppUserPrincipal principal,
                                               @Valid @RequestBody RecurringSlotRequest req) {
        return teacherService.createRecurringSlots(principal.getId(), req);
    }

    @DeleteMapping("/slots/series/{recurrenceGroupId}")
    public void cancelSlotSeries(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable String recurrenceGroupId) {
        teacherService.cancelSlotSeries(principal.getId(), recurrenceGroupId);
    }

    @GetMapping("/slots/mine")
    public List<SlotDto> mySlots(@AuthenticationPrincipal AppUserPrincipal principal) {
        return teacherService.slotsForTeacher(principal.getId());
    }

    @GetMapping("/{teacherId}/courses/{courseId}/slots")
    public List<SlotDto> slotsForTeacherAndCourse(@PathVariable Long teacherId, @PathVariable Long courseId) {
        return teacherService.slotsForTeacherAndCourse(teacherId, courseId);
    }

    // The teacher's busy/blocked windows for one day, across ALL their courses.
    @GetMapping("/{teacherId}/busy")
    public List<BusyRangeDto> busy(@PathVariable Long teacherId, @RequestParam String date) {
        return teacherService.busyRanges(teacherId, LocalDate.parse(date));
    }

    @DeleteMapping("/slots/{slotId}")
    public void cancelSlot(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long slotId) {
        teacherService.cancelSlot(principal.getId(), slotId);
    }
}
