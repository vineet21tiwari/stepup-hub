package com.stepuphub.controller;

import com.stepuphub.dto.AssignmentDto;
import com.stepuphub.dto.AssignmentRequest;
import com.stepuphub.dto.GradeRequest;
import com.stepuphub.dto.SubmissionDto;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.AssignmentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/assignments")
@RequiredArgsConstructor
public class AssignmentController {

    private final AssignmentService assignmentService;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AssignmentDto create(@AuthenticationPrincipal AppUserPrincipal principal,
                                 @RequestPart("data") AssignmentRequest req,
                                 @RequestPart(value = "attachment", required = false) MultipartFile attachment) {
        return assignmentService.createAssignment(principal.getId(), req, attachment);
    }

    @GetMapping("/course/{courseId}")
    public List<AssignmentDto> forCourse(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long courseId) {
        return assignmentService.getAssignmentsForCourse(principal.getId(), courseId);
    }

    @GetMapping("/{id}")
    public AssignmentDto get(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return assignmentService.getAssignment(principal.getId(), id);
    }

    @PostMapping("/{id}/submit")
    public SubmissionDto submit(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                                 @RequestParam(value = "file", required = false) MultipartFile file,
                                 @RequestParam(value = "textAnswer", required = false) String textAnswer) {
        return assignmentService.submitAssignment(principal.getId(), id, file, textAnswer);
    }

    @GetMapping("/{id}/submissions")
    public List<SubmissionDto> submissions(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return assignmentService.listSubmissions(principal.getId(), id);
    }

    @GetMapping("/{id}/submissions/mine")
    public SubmissionDto mySubmission(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return assignmentService.mySubmission(principal.getId(), id);
    }

    @PostMapping("/{id}/submissions/{submissionId}/grade")
    public SubmissionDto grade(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id,
                                @PathVariable Long submissionId, @Valid @RequestBody GradeRequest req) {
        return assignmentService.gradeSubmission(principal.getId(), id, submissionId, req);
    }
}