package com.stepuphub.service;

import com.stepuphub.domain.Notification;
import com.stepuphub.domain.User;
import com.stepuphub.dto.NotificationDto;
import com.stepuphub.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final SimpMessagingTemplate messagingTemplate;

    @Transactional
    public void notify(User user, Notification.NotificationType type, String message, String relatedEntity) {
        Notification n = new Notification();
        n.setUser(user);
        n.setType(type);
        n.setMessage(message);
        n.setRelatedEntity(relatedEntity);
        notificationRepository.save(n);
        // Push over websocket to /topic/user/{userId} for realtime clients.
        messagingTemplate.convertAndSend("/topic/user/" + user.getId(), NotificationDto.from(n));
    }

    @Transactional(readOnly = true)
    public List<NotificationDto> listForUser(Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId)
                .stream().map(NotificationDto::from).toList();
    }

    @Transactional
    public void markRead(Long notificationId, Long requestingUserId) {
        Notification n = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new IllegalArgumentException("Notification not found"));
        if (!n.getUser().getId().equals(requestingUserId)) {
            throw new IllegalArgumentException("Not your notification");
        }
        n.setRead(true);
        notificationRepository.save(n);
    }
}
