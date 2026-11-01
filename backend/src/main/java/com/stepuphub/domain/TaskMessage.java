package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

// The file-sharing thread attached to one Task — same shape as DirectMessage, scoped to a task
// instead of a user pair. Participants are always just that task's admin and coordinator.
@Entity
@Table(name = "task_messages")
@Data
@NoArgsConstructor
public class TaskMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "task_id")
    private Task task;

    @ManyToOne(optional = false)
    @JoinColumn(name = "sender_id")
    private User sender;

    @Column(length = 4000)
    private String content;

    private String attachmentUrl;

    private String attachmentName;

    @Column(updatable = false)
    private Instant sentAt = Instant.now();
}
