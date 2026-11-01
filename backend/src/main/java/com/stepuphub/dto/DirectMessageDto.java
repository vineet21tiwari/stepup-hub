package com.stepuphub.dto;

import com.stepuphub.domain.DirectMessage;

import java.time.Instant;

public record DirectMessageDto(Long id, Long senderId, String senderName, Long recipientId, String content,
                                String attachmentUrl, String attachmentName, Instant sentAt) {
    public static DirectMessageDto from(DirectMessage m) {
        return new DirectMessageDto(m.getId(), m.getSender().getId(), m.getSender().getName(),
                m.getRecipient().getId(), m.getContent(), m.getAttachmentUrl(), m.getAttachmentName(), m.getSentAt());
    }
}
