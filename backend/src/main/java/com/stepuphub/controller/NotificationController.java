package com.stepuphub.controller;

import com.stepuphub.dto.NotificationDto;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping
    public List<NotificationDto> list(@AuthenticationPrincipal AppUserPrincipal principal) {
        return notificationService.listForUser(principal.getId());
    }

    @PostMapping("/{id}/read")
    public void markRead(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        notificationService.markRead(id, principal.getId());
    }
}
