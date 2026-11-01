package com.stepuphub.dto;

import com.stepuphub.domain.TaskMessage;

import java.time.Instant;

public record TaskMessageDto(Long id, Long taskId, Long senderId, String senderName, String content,
                              String attachmentUrl, String attachmentName, Instant sentAt) {
    public static TaskMessageDto from(TaskMessage m) {
        return new TaskMessageDto(m.getId(), m.getTask().getId(), m.getSender().getId(), m.getSender().getName(),
                m.getContent(), m.getAttachmentUrl(), m.getAttachmentName(), m.getSentAt());
    }
}
