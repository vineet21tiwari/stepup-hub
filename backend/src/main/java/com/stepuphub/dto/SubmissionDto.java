package com.stepuphub.dto;

import com.stepuphub.domain.AssignmentSubmission;

import java.time.Instant;

public record SubmissionDto(Long id, Long assignmentId, Long studentId, String studentName, Instant submittedAt,
                             String fileUrl, String textAnswer, String grade, String feedback, String status) {
    public static SubmissionDto from(AssignmentSubmission s) {
        return new SubmissionDto(s.getId(), s.getAssignment().getId(), s.getStudent().getId(), s.getStudent().getName(),
                s.getSubmittedAt(), s.getFileUrl(), s.getTextAnswer(), s.getGrade(), s.getFeedback(), s.getStatus().name());
    }
}