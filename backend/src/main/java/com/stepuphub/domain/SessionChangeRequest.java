package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * A request to reschedule or cancel one scheduled class. Allowed only for classes on a later calendar
 * day than today (never on the class day itself).
 * - Raised by the TEACHER: every student in the class AND an admin must approve.
 * - Raised by a STUDENT: the teacher AND an admin must approve.
 * Any rejection rejects the whole request. Once every approval is in, the change is applied.
 */
@Entity
@Table(name = "session_change_requests")
@Data
@NoArgsConstructor
public class SessionChangeRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "session_id")
    private ClassSession session;

    @ManyToOne(optional = false)
    @JoinColumn(name = "requested_by_id")
    private User requestedBy;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "VARCHAR(20)")
    private Role requesterRole;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "VARCHAR(20)")
    private ChangeType type;

    // Proposed new time (RESCHEDULE only).
    private Instant newStart;
    private Instant newEnd;

    // Time of the class when the request was raised (for display after it's applied).
    private Instant originalStart;
    private Instant originalEnd;

    @Column(length = 1000)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "VARCHAR(20)")
    private ChangeStatus status = ChangeStatus.PENDING;

    // Teacher-raised: comma-separated ids of students who approved. Student-raised: unused.
    @Column(length = 1000)
    private String approvedStudentIds = "";

    // Student-raised: teacher approved.
    private boolean teacherApproved = false;

    private boolean adminApproved = false;

    @ManyToOne
    @JoinColumn(name = "decided_by_id")
    private User rejectedBy;

    @Column(length = 1000)
    private String decisionNote;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();

    private Instant decidedAt;

    public enum ChangeType { RESCHEDULE, CANCEL }

    public enum ChangeStatus { PENDING, APPROVED, REJECTED, WITHDRAWN }
}
