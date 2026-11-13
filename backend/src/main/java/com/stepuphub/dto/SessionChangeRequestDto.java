package com.stepuphub.dto;

import java.time.Instant;
import java.util.List;

/**
 * awaiting lists who still has to approve (e.g. ["Admin", "Riya Sharma"]). canDecide is true when the
 * viewer is one of them; canWithdraw when the viewer raised it and it's still pending.
 */
public record SessionChangeRequestDto(Long id, Long sessionId, Long courseId, String courseTitle, String teacherName,
                                      List<String> studentNames, String type, String status,
                                      Instant originalStart, Instant originalEnd, Instant newStart, Instant newEnd,
                                      String reason, Long requestedById, String requestedByName, String requesterRole,
                                      List<String> approvedBy, List<String> awaiting, boolean canDecide, boolean canWithdraw,
                                      String rejectedByName, String decisionNote, Instant createdAt, Instant decidedAt) {}
