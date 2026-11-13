package com.stepuphub.controller;

import com.stepuphub.dto.AttendanceRequest;
import com.stepuphub.dto.DecisionRequest;
import com.stepuphub.dto.SessionChangeRequestBody;
import com.stepuphub.dto.SessionChangeRequestDto;
import com.stepuphub.service.SessionChangeService;
import com.stepuphub.dto.ClassSessionDto;
import com.stepuphub.dto.MeetingLinkRequest;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.ClassSessionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/sessions")
@RequiredArgsConstructor
public class ClassSessionController {

    private final ClassSessionService classSessionService;
    private final SessionChangeService sessionChangeService;

    // ---- Reschedule / cancel requests (see SessionChangeRequest for the approval rules) ----
    @PostMapping("/{id}/change-requests")
    public SessionChangeRequestDto requestChange(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                                                 @Valid @RequestBody SessionChangeRequestBody body) {
        return sessionChangeService.create(principal.getId(), id, body);
    }

    @GetMapping("/{id}/change-requests")
    public List<SessionChangeRequestDto> changeRequestsForSession(@AuthenticationPrincipal AppUserPrincipal principal,
                                                                  @PathVariable Long id) {
        return sessionChangeService.forSession(principal.getId(), id);
    }

    @GetMapping("/change-requests/mine")
    public List<SessionChangeRequestDto> myChangeRequests(@AuthenticationPrincipal AppUserPrincipal principal) {
        return sessionChangeService.mine(principal.getId());
    }

    @PostMapping("/change-requests/{requestId}/decide")
    public SessionChangeRequestDto decideChange(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long requestId,
                                                @RequestBody DecisionRequest decision) {
        return sessionChangeService.decide(principal.getId(), requestId, decision.isApprove(), decision.getNote());
    }

    @DeleteMapping("/change-requests/{requestId}")
    public void withdrawChange(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long requestId) {
        sessionChangeService.withdraw(principal.getId(), requestId);
    }

    @GetMapping("/mine")
    public List<ClassSessionDto> mine(@AuthenticationPrincipal AppUserPrincipal principal) {
        return classSessionService.forCurrentUser(principal.getId());
    }

    @GetMapping("/course/{courseId}")
    public List<ClassSessionDto> forCourse(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long courseId) {
        return classSessionService.forCourse(principal.getId(), courseId);
    }

    @GetMapping("/{id}")
    public ClassSessionDto get(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return classSessionService.get(id, principal.getId());
    }

    @PutMapping("/{id}/meeting")
    public ClassSessionDto setMeetingLink(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                                           @Valid @RequestBody MeetingLinkRequest req) {
        return classSessionService.setMeetingLink(principal.getId(), id, req.getMeetingLink());
    }

    @DeleteMapping("/{id}/meeting")
    public ClassSessionDto clearMeetingLink(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return classSessionService.clearMeetingLink(principal.getId(), id);
    }

    // Coordinator (assigned to this course) or admin only — see ClassSessionService.markAttendance.
    @PutMapping("/{id}/attendance")
    public ClassSessionDto markAttendance(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                                           @Valid @RequestBody AttendanceRequest req) {
        return classSessionService.markAttendance(principal.getId(), id, req);
    }
}
