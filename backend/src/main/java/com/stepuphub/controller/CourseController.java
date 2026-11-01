package com.stepuphub.controller;

import com.stepuphub.dto.CourseDto;
import com.stepuphub.dto.CourseRequest;
import com.stepuphub.dto.CourseTeacherDto;
import com.stepuphub.dto.UserSummaryDto;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.CourseCoordinatorService;
import com.stepuphub.service.CourseService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/courses")
@RequiredArgsConstructor
public class CourseController {

    private final CourseService courseService;
    private final CourseCoordinatorService courseCoordinatorService;

    @GetMapping
    public List<CourseDto> list() {
        return courseService.listActiveCourses();
    }

    // Admin-curated highlights for the public homepage.
    @GetMapping("/featured")
    public List<CourseDto> featured() {
        return courseService.listFeaturedCourses();
    }

    @GetMapping("/{id}")
    public CourseDto get(@PathVariable Long id) {
        return courseService.getCourse(id);
    }

    // Teachers approved for this course, each with their resume + this course's intro video,
    // so a student can decide which teacher to book.
    @GetMapping("/{id}/teachers")
    public List<CourseTeacherDto> teachersForCourse(@PathVariable Long id) {
        return courseService.approvedTeachersForCourse(id);
    }

    // The curriculum PDF is optional — the frontend always sends multipart form data (a JSON
    // "data" part plus an optional "curriculum" file part), matching SiteContentController's
    // updatePage pattern for the same "entity + optional file" shape.
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CourseDto create(@AuthenticationPrincipal AppUserPrincipal principal, @Valid @RequestPart("data") CourseRequest req,
                             @RequestPart(value = "curriculum", required = false) MultipartFile curriculum) {
        return courseService.createCourse(principal.getId(), req, curriculum);
    }

    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CourseDto update(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                             @Valid @RequestPart("data") CourseRequest req,
                             @RequestPart(value = "curriculum", required = false) MultipartFile curriculum) {
        return courseService.updateCourse(principal.getId(), id, req, curriculum);
    }

    @DeleteMapping("/{id}")
    public void deactivate(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        courseService.deactivateCourse(principal.getId(), id);
    }

    // ---- Course-level coordinator assignment (covers every class in the course) ----
    @GetMapping("/{id}/coordinators")
    public List<UserSummaryDto> coordinators(@PathVariable Long id) {
        return courseCoordinatorService.listForCourse(id);
    }

    @PostMapping("/{id}/coordinators/{coordinatorId}")
    public UserSummaryDto assignCoordinator(@AuthenticationPrincipal AppUserPrincipal principal,
                                             @PathVariable Long id, @PathVariable Long coordinatorId) {
        return courseCoordinatorService.assign(principal.getId(), id, coordinatorId);
    }

    @DeleteMapping("/{id}/coordinators/{coordinatorId}")
    public void unassignCoordinator(@AuthenticationPrincipal AppUserPrincipal principal,
                                     @PathVariable Long id, @PathVariable Long coordinatorId) {
        courseCoordinatorService.unassign(principal.getId(), id, coordinatorId);
    }
}
