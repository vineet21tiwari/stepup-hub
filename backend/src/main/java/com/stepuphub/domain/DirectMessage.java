package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

// Private 1:1 messaging, scoped to Admin<->Coordinator pairs only (see DirectMessageService) — not a
// general platform-wide DM feature. Content is nullable since a message can be attachment-only.
@Entity
@Table(name = "direct_messages")
@Data
@NoArgsConstructor
public class DirectMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "sender_id")
    private User sender;

    @ManyToOne(optional = false)
    @JoinColumn(name = "recipient_id")
    private User recipient;

    @Column(length = 4000)
    private String content;

    private String attachmentUrl;

    private String attachmentName;

    @Column(updatable = false)
    private Instant sentAt = Instant.now();
}
