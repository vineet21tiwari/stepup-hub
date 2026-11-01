package com.stepuphub.controller;

import com.stepuphub.domain.User;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.CourseAccessService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Tells the course page what the current user may see/do there, so it can show the right controls. */
@RestController
@RequestMapping("/api/course-access")
@RequiredArgsConstructor
public class CourseAccessController {

    private final CourseAccessService courseAccessService;

    public record CourseAccessDto(boolean member, boolean canManage) {
    }

    @GetMapping("/{courseId}")
    public CourseAccessDto access(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long courseId) {
        User user = courseAccessService.requireUser(principal.getId());
        return new CourseAccessDto(courseAccessService.isMember(courseId, user), courseAccessService.canManage(courseId, user));
    }
}
