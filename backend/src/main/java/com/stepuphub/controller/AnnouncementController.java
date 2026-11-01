package com.stepuphub.controller;

import com.stepuphub.dto.AnnouncementDto;
import com.stepuphub.dto.AnnouncementRequest;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.AnnouncementService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/announcements")
@RequiredArgsConstructor
public class AnnouncementController {

    private final AnnouncementService announcementService;

    @PostMapping
    public AnnouncementDto create(@AuthenticationPrincipal AppUserPrincipal principal, @Valid @RequestBody AnnouncementRequest req) {
        return announcementService.create(principal.getId(), req);
    }

    @GetMapping
    public List<AnnouncementDto> listAll() {
        return announcementService.listAll();
    }

    @GetMapping("/{id}")
    public AnnouncementDto get(@PathVariable Long id) {
        return announcementService.get(id);
    }

    @PutMapping("/{id}")
    public AnnouncementDto update(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                                   @Valid @RequestBody AnnouncementRequest req) {
        return announcementService.update(principal.getId(), id, req);
    }

    @DeleteMapping("/{id}")
    public void delete(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        announcementService.delete(principal.getId(), id);
    }

    @GetMapping("/global")
    public List<AnnouncementDto> listGlobal() {
        return announcementService.listGlobal();
    }

    @GetMapping("/course/{courseId}")
    public List<AnnouncementDto> listForCourse(@PathVariable Long courseId) {
        return announcementService.listForCourse(courseId);
    }
}