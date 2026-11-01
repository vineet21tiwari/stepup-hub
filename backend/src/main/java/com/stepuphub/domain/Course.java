package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Entity
@Table(name = "courses")
@Data
@NoArgsConstructor
public class Course {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(length = 2000)
    private String description;

    private String subject;

    @ManyToOne
    @JoinColumn(name = "created_by_admin_id")
    private User createdBy;

    private boolean active = true;

    // Admin-curated flag to highlight this course on the public homepage.
    private boolean featured = false;

    // Optional curriculum brochure (PDF), e.g. "/uploads/curricula/xyz.pdf"
    private String curriculumUrl;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();
}
