package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * An admin-authored announcement. GLOBAL announcements go to every user;
 * COURSE announcements go to that course's approved teachers, enrolled students,
 * and any coordinators assigned to that course's sessions.
 */
@Entity
@Table(name = "announcements")
@Data
@NoArgsConstructor
public class Announcement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, length = 2000)
    private String message;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AnnouncementScope scope;

    // Set only when scope == COURSE
    @ManyToOne
    @JoinColumn(name = "course_id")
    private Course course;

    @ManyToOne(optional = false)
    @JoinColumn(name = "created_by_admin_id")
    private User createdBy;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();
}