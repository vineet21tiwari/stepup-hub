package com.stepuphub.controller;

import com.stepuphub.dto.AttendanceRequest;
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
