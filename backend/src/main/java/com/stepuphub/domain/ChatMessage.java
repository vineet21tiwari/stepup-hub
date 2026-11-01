package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Entity
@Table(name = "chat_messages")
@Data
@NoArgsConstructor
public class ChatMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Chat is scoped to the whole course (one thread covering every class in it), not one class
    // session at a time — nullable only so Hibernate's ddl-auto=update can add this column onto an
    // existing table without failing on old rows; every message written by the app always sets it.
    @ManyToOne
    @JoinColumn(name = "course_id")
    private Course course;

    @ManyToOne(optional = false)
    @JoinColumn(name = "sender_id")
    private User sender;

    @Column(length = 4000, nullable = false)
    private String content;

    @Column(updatable = false)
    private Instant sentAt = Instant.now();
}
