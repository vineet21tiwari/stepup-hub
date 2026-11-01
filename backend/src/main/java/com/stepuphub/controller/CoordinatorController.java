package com.stepuphub.controller;

import com.stepuphub.dto.CourseDto;
import com.stepuphub.service.CourseCoordinatorService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/coordinators")
@RequiredArgsConstructor
public class CoordinatorController {

    private final CourseCoordinatorService courseCoordinatorService;

    // Which courses a coordinator covers — used by admin ("who's assigned where") and by the
    // coordinator's own dashboard ("my courses").
    @GetMapping("/{id}/courses")
    public List<CourseDto> coursesFor(@PathVariable Long id) {
        return courseCoordinatorService.listCoursesForCoordinator(id);
    }
}
