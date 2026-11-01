package com.stepuphub.controller;

import com.stepuphub.domain.Role;
import com.stepuphub.domain.User;
import com.stepuphub.dto.CreateUserRequest;
import com.stepuphub.dto.PasswordResetResultDto;
import com.stepuphub.dto.UserSummaryDto;
import com.stepuphub.dto.UserUpdateRequest;
import com.stepuphub.repository.UserRepository;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.FileStorageService;
import com.stepuphub.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;
    private final FileStorageService fileStorageService;
    private final UserService userService;

    @GetMapping("/me")
    public UserSummaryDto me(@AuthenticationPrincipal AppUserPrincipal principal) {
        return UserSummaryDto.from(principal.getUser());
    }

    // Lets a teacher who skipped the resume at signup add/replace one later.
    @PostMapping(value = "/me/resume", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public UserSummaryDto uploadResume(@AuthenticationPrincipal AppUserPrincipal principal,
                                        @RequestParam("resume") MultipartFile resume) {
        User user = userRepository.findById(principal.getId())
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        if (user.getRole() != Role.TEACHER) {
            throw new IllegalArgumentException("Only teachers can upload a resume");
        }
        if (resume == null || resume.isEmpty()) {
            throw new IllegalArgumentException("A resume file is required");
        }
        user.setResumeUrl(fileStorageService.store("resumes", resume));
        userRepository.save(user);
        return UserSummaryDto.from(user);
    }

    // Admin/coordinator use: list users by role, e.g. /api/users?role=COORDINATOR
    @GetMapping
    public List<UserSummaryDto> byRole(@RequestParam(required = false) Role role) {
        List<User> users = role != null ? userRepository.findByRole(role) : userRepository.findAll();
        return users.stream().map(UserSummaryDto::from).toList();
    }

    // ---- Admin user management ----
    // Admin-provisioned Admin/Coordinator accounts (students/teachers self-signup instead).
    @PostMapping
    public UserSummaryDto create(@AuthenticationPrincipal AppUserPrincipal principal, @Valid @RequestBody CreateUserRequest req) {
        return userService.createUser(principal.getId(), req);
    }

    @PostMapping("/{id}/reset-password")
    public PasswordResetResultDto resetPassword(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return userService.resetPassword(principal.getId(), id);
    }

    @PutMapping("/{id}")
    public UserSummaryDto update(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                                  @Valid @RequestBody UserUpdateRequest req) {
        return userService.update(principal.getId(), id, req);
    }

    @PostMapping("/{id}/deactivate")
    public UserSummaryDto deactivate(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return userService.setActive(principal.getId(), id, false);
    }

    @PostMapping("/{id}/reactivate")
    public UserSummaryDto reactivate(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return userService.setActive(principal.getId(), id, true);
    }
}
