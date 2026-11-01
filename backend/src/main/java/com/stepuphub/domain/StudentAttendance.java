package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

// One row per student per class session once attendance is marked (see ClassSessionService.markAttendance).
// Re-marking a session replaces its rows rather than accumulating duplicates.
@Entity
@Table(name = "student_attendance", uniqueConstraints = @UniqueConstraint(columnNames = {"session_id", "student_id"}))
@Data
@NoArgsConstructor
public class StudentAttendance {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "session_id")
    private ClassSession session;

    @ManyToOne(optional = false)
    @JoinColumn(name = "student_id")
    private User student;

    @Column(nullable = false)
    private boolean present;
}
