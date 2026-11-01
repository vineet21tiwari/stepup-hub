package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Entity
@Table(name = "testimonials")
@Data
@NoArgsConstructor
public class Testimonial {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String authorName;

    // e.g. "Parent of Grade 8 student", "Batch of 2025"
    private String authorRole;

    @Column(nullable = false, length = 2000)
    private String message;

    // 1-5, optional
    private Integer rating;

    private String photoUrl;

    private boolean published = true;

    private int displayOrder = 0;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();
}