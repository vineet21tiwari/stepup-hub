package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * A student's request to book a Slot. Flow:
 * PENDING_TEACHER -> (teacher approves) -> PENDING_ADMIN -> (admin approves) -> APPROVED
 * At approval, a ClassSession is created/linked and the student is added to it.
 */
@Entity
@Table(name = "enrollment_requests")
@Data
@NoArgsConstructor
public class EnrollmentRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "student_id")
    private User student;

    @ManyToOne(optional = false)
    @JoinColumn(name = "slot_id")
    private Slot slot;

    @Enumerated(EnumType.STRING)
    private RequestStatus status = RequestStatus.PENDING_TEACHER;

    private String teacherNote;
    private String adminNote;

    // Shared by every EnrollmentRequest created from one bookRecurring() call (one weekday's worth of
    // dated Slot occurrences), so the whole weekly commitment can be approved/rejected as a unit.
    // Null for a plain one-off single-slot booking.
    private String batchId;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();

    private Instant decidedAt;
}
