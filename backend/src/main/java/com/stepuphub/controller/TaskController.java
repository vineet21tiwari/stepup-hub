package com.stepuphub.controller;

import com.stepuphub.domain.Role;
import com.stepuphub.dto.TaskDto;
import com.stepuphub.dto.TaskMessageDto;
import com.stepuphub.dto.TaskRequest;
import com.stepuphub.dto.TaskStatusRequest;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.TaskService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/tasks")
@RequiredArgsConstructor
public class TaskController {

    private final TaskService taskService;

    @PostMapping
    public TaskDto create(@AuthenticationPrincipal AppUserPrincipal principal, @Valid @RequestBody TaskRequest req) {
        return taskService.create(principal.getId(), req);
    }

    // Role-aware: a coordinator sees tasks assigned to them, an admin sees tasks they created.
    @GetMapping("/mine")
    public List<TaskDto> mine(@AuthenticationPrincipal AppUserPrincipal principal) {
        return principal.getUser().getRole() == Role.ADMIN
                ? taskService.listCreatedByAdmin(principal.getId())
                : taskService.listForCoordinator(principal.getId());
    }

    @PutMapping("/{id}/status")
    public TaskDto updateStatus(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                                 @Valid @RequestBody TaskStatusRequest req) {
        return taskService.updateStatus(principal.getId(), id, req.getStatus());
    }

    @GetMapping("/{id}/messages")
    public List<TaskMessageDto> messages(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return taskService.messages(id, principal.getId());
    }

    @PostMapping("/{id}/messages/send")
    public TaskMessageDto sendMessage(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                                       @RequestParam(required = false) String content,
                                       @RequestParam(required = false) MultipartFile attachment) {
        return taskService.sendMessage(id, principal.getId(), content, attachment);
    }
}
