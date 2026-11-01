package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

// A coordinator assigned to a course — covers every class in it. Replaces the earlier
// per-class-session coordinator assignment; a course may have multiple coordinators.
@Entity
@Table(name = "course_coordinators", uniqueConstraints = @UniqueConstraint(columnNames = {"course_id", "coordinator_id"}))
@Data
@NoArgsConstructor
public class CourseCoordinator {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "course_id")
    private Course course;

    @ManyToOne(optional = false)
    @JoinColumn(name = "coordinator_id")
    private User coordinator;

    @Column(updatable = false)
    private Instant assignedAt = Instant.now();
}
