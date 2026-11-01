package com.stepuphub.dto;

import com.stepuphub.domain.Notification;

import java.time.Instant;

public record NotificationDto(Long id, String type, String message, String relatedEntity, boolean read, Instant createdAt) {
    public static NotificationDto from(Notification n) {
        return new NotificationDto(n.getId(), n.getType().name(), n.getMessage(), n.getRelatedEntity(), n.isRead(), n.getCreatedAt());
    }
}
