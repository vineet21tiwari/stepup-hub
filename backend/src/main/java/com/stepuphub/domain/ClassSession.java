package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "class_sessions")
@Data
@NoArgsConstructor
public class ClassSession {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "course_id")
    private Course course;

    @ManyToOne(optional = false)
    @JoinColumn(name = "teacher_id")
    private User teacher;

    @ManyToOne
    @JoinColumn(name = "slot_id")
    private Slot slot;

    @ManyToMany
    @JoinTable(
            name = "class_session_students",
            joinColumns = @JoinColumn(name = "session_id"),
            inverseJoinColumns = @JoinColumn(name = "student_id")
    )
    private Set<User> students = new HashSet<>();

    @Column(nullable = false)
    private Instant scheduledStart;

    @Column(nullable = false)
    private Instant scheduledEnd;

    @Enumerated(EnumType.STRING)
    private SessionStatus status = SessionStatus.SCHEDULED;

    private boolean reminderSent = false;

    // Zoom or Google Meet link the teacher adds to start this class (see ClassSessionService.setMeetingLink).
    @Column(length = 1000)
    private String meetingLink;

    // Attendance, recorded manually by a coordinator (or admin) after the class — see
    // ClassSessionService.markAttendance. Null until marked. Per-student presence lives in
    // StudentAttendance; actualStart/actualEnd let the UI compute how long the class actually ran.
    private Instant actualStart;
    private Instant actualEnd;
    private Boolean teacherPresent;
    private Instant attendanceMarkedAt;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();

    public enum SessionStatus {
        SCHEDULED, ONGOING, COMPLETED, CANCELLED
    }
}
