package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Entity
@Table(name = "notifications")
@Data
@NoArgsConstructor
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "VARCHAR(40)")
    private NotificationType type;

    @Column(nullable = false, length = 1000)
    private String message;

    // Generic pointer so the client can open the related screen, e.g. "SESSION:12", "ENROLLMENT_REQUEST:5"
    private String relatedEntity;

    @Column(name = "is_read", nullable = false)
    private boolean read = false;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();

    public enum NotificationType {
        CLASS_REMINDER,
        ENROLLMENT_REQUEST_CREATED,
        ENROLLMENT_APPROVED_BY_TEACHER,
        ENROLLMENT_REJECTED_BY_TEACHER,
        ENROLLMENT_APPROVED,
        ENROLLMENT_REJECTED,
        TEACHER_APPLICATION_SUBMITTED,
        TEACHER_APPLICATION_APPROVED,
        TEACHER_APPLICATION_REJECTED,
        SESSION_SCHEDULED,
        SESSION_CANCELLED,
        NEW_CHAT_MESSAGE,
        MEETING_LINK_ADDED,
        ANNOUNCEMENT,
        ASSIGNMENT_POSTED,
        ASSIGNMENT_SUBMITTED,
        ASSIGNMENT_GRADED,
        GENERAL
    }
}
