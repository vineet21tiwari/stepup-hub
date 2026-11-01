package com.stepuphub.controller;

import com.stepuphub.dto.DecisionRequest;
import com.stepuphub.dto.EnrollmentRequestDto;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.EnrollmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/enrollment-requests")
@RequiredArgsConstructor
public class EnrollmentController {

    private final EnrollmentService enrollmentService;

    @PostMapping("/book/{slotId}")
    public EnrollmentRequestDto book(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long slotId) {
        return enrollmentService.bookSlot(principal.getId(), slotId);
    }

    // Books a whole weekly commitment at once: one chosen Slot id per weekday required by the plan.
    @PostMapping("/book-recurring")
    public List<EnrollmentRequestDto> bookRecurring(@AuthenticationPrincipal AppUserPrincipal principal,
                                                      @RequestBody List<Long> slotIds) {
        return enrollmentService.bookRecurring(principal.getId(), slotIds);
    }

    @GetMapping("/mine")
    public List<EnrollmentRequestDto> mine(@AuthenticationPrincipal AppUserPrincipal principal) {
        return enrollmentService.requestsForStudent(principal.getId());
    }

    // Lets a student withdraw their own booking request before it's fully approved.
    @DeleteMapping("/{id}")
    public void cancel(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        enrollmentService.cancelRequest(principal.getId(), id);
    }

    @GetMapping("/pending-for-teacher")
    public List<EnrollmentRequestDto> pendingForTeacher(@AuthenticationPrincipal AppUserPrincipal principal) {
        return enrollmentService.pendingForTeacher(principal.getId());
    }

    @GetMapping("/pending-for-admin")
    public List<EnrollmentRequestDto> pendingForAdmin() {
        return enrollmentService.pendingForAdmin();
    }

    @PostMapping("/{id}/teacher-decide")
    public EnrollmentRequestDto teacherDecide(@AuthenticationPrincipal AppUserPrincipal principal,
                                               @PathVariable Long id, @RequestBody DecisionRequest decision) {
        return enrollmentService.teacherDecide(principal.getId(), id, decision);
    }

    @PostMapping("/{id}/admin-decide")
    public EnrollmentRequestDto adminDecide(@AuthenticationPrincipal AppUserPrincipal principal,
                                             @PathVariable Long id, @RequestBody DecisionRequest decision) {
        return enrollmentService.adminDecide(principal.getId(), id, decision);
    }
}
