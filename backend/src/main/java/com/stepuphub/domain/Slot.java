package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * A single bookable time slot offered by a teacher for a specific course.
 */
@Entity
@Table(name = "slots")
@Data
@NoArgsConstructor
public class Slot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "teacher_id")
    private User teacher;

    @ManyToOne(optional = false)
    @JoinColumn(name = "course_id")
    private Course course;

    @Column(nullable = false)
    private Instant startTime;

    @Column(nullable = false)
    private Instant endTime;

    @Column(nullable = false)
    private int capacity = 1;

    @Column(nullable = false)
    private int bookedCount = 0;

    private boolean cancelled = false;

    // Shared across all occurrences generated from one recurring-availability request, so a
    // teacher can bulk-cancel "the whole series" instead of one slot at a time. Null for one-off slots.
    private String recurrenceGroupId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "VARCHAR(20)")
    private SessionType sessionType = SessionType.ONE_ON_ONE;

    // How many of these per week the course requires a student to pick (0 for one-off, non-recurring slots).
    // Denormalized onto every occurrence generated from the same recurring-availability request.
    @Column(nullable = false)
    private int classesPerWeek = 0;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();

    @Transient
    public boolean isFull() {
        return bookedCount >= capacity;
    }
}
