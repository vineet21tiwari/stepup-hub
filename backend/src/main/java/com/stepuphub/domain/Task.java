package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

// A task an admin assigns to a coordinator, with a deadline. Course link is optional — a task can be
// general admin work or tied to a specific course (e.g. "prep materials for Python A-Z").
@Entity
@Table(name = "tasks")
@Data
@NoArgsConstructor
public class Task {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(length = 2000)
    private String description;

    @ManyToOne
    @JoinColumn(name = "course_id")
    private Course course;

    @ManyToOne(optional = false)
    @JoinColumn(name = "assigned_by_id")
    private User assignedBy;

    @ManyToOne(optional = false)
    @JoinColumn(name = "coordinator_id")
    private User coordinator;

    @Column(nullable = false)
    private Instant deadline;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "VARCHAR(20)")
    private TaskStatus status = TaskStatus.PENDING;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();

    public enum TaskStatus {
        PENDING, IN_PROGRESS, DONE
    }
}
