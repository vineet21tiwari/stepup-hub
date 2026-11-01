package com.stepuphub.dto;

import com.stepuphub.domain.ChatMessage;

import java.time.Instant;

public record ChatMessageDto(Long id, Long courseId, Long senderId, String senderName, String senderRole,
                              String content, Instant sentAt) {
    public static ChatMessageDto from(ChatMessage m) {
        return new ChatMessageDto(m.getId(), m.getCourse().getId(), m.getSender().getId(),
                m.getSender().getName(), m.getSender().getRole().name(), m.getContent(), m.getSentAt());
    }
}
