package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/** A plain post on a course's feed, written by any member of the course. Others can only like it. */
@Entity
@Table(name = "course_posts")
@Data
@NoArgsConstructor
public class CoursePost {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "course_id")
    private Course course;

    @ManyToOne(optional = false)
    @JoinColumn(name = "author_id")
    private User author;

    @Column(nullable = false, length = 2000)
    private String content;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();
}
