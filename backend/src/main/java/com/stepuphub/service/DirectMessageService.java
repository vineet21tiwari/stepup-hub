package com.stepuphub.service;

import com.stepuphub.domain.DirectMessage;
import com.stepuphub.domain.Notification;
import com.stepuphub.domain.Role;
import com.stepuphub.domain.User;
import com.stepuphub.dto.DirectMessageDto;
import com.stepuphub.repository.DirectMessageRepository;
import com.stepuphub.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

/**
 * Private 1:1 messaging between Admin and Coordinator accounts only (not a general DM feature —
 * see requirePairing). Supports an optional file attachment per message (image/PDF), reusing
 * FileStorageService the same way resumes/curriculum/assignments do.
 */
@Service
@RequiredArgsConstructor
public class DirectMessageService {

    private final DirectMessageRepository directMessageRepository;
    private final UserRepository userRepository;
    private final FileStorageService fileStorageService;
    private final NotificationService notificationService;
    private final SimpMessagingTemplate messagingTemplate;

    private User requireUser(Long userId) {
        return userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));
    }

    // This stays scoped to the Admin<->Coordinator pairing on purpose, not a general messaging platform.
    private void requirePairing(User a, User b) {
        boolean valid = (a.getRole() == Role.ADMIN && b.getRole() == Role.COORDINATOR)
                || (a.getRole() == Role.COORDINATOR && b.getRole() == Role.ADMIN);
        if (!valid) throw new IllegalArgumentException("This chat is only between an admin and a coordinator");
    }

    private String topicFor(Long userIdA, Long userIdB) {
        long lo = Math.min(userIdA, userIdB);
        long hi = Math.max(userIdA, userIdB);
        return "/topic/dm/" + lo + "-" + hi;
    }

    @Transactional
    public DirectMessageDto send(Long senderId, Long recipientId, String content, MultipartFile attachment) {
        User sender = requireUser(senderId);
        User recipient = requireUser(recipientId);
        requirePairing(sender, recipient);
        boolean hasText = content != null && !content.isBlank();
        boolean hasFile = attachment != null && !attachment.isEmpty();
        if (!hasText && !hasFile) {
            throw new IllegalArgumentException("Message cannot be empty");
        }

        DirectMessage msg = new DirectMessage();
        msg.setSender(sender);
        msg.setRecipient(recipient);
        msg.setContent(hasText ? content.trim() : null);
        if (hasFile) {
            msg.setAttachmentUrl(fileStorageService.store("dm-attachments", attachment));
            msg.setAttachmentName(attachment.getOriginalFilename());
        }
        msg = directMessageRepository.save(msg);

        DirectMessageDto dto = DirectMessageDto.from(msg);
        messagingTemplate.convertAndSend(topicFor(senderId, recipientId), dto);

        String preview = hasText ? (content.length() > 80 ? content.substring(0, 80) + "..." : content) : "sent a file";
        notificationService.notify(recipient, Notification.NotificationType.NEW_CHAT_MESSAGE,
                sender.getName() + ": " + preview, "DM:" + senderId);

        return dto;
    }

    @Transactional(readOnly = true)
    public List<DirectMessageDto> history(Long userId, Long otherUserId) {
        User user = requireUser(userId);
        User other = requireUser(otherUserId);
        requirePairing(user, other);
        return directMessageRepository.findConversation(userId, otherUserId)
                .stream().map(DirectMessageDto::from).toList();
    }
}
