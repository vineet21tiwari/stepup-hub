package com.stepuphub.controller;

import com.stepuphub.dto.ChatMessageDto;
import com.stepuphub.dto.ChatSendRequest;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.ChatService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;

@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    // REST fallback / initial history load. Realtime delivery happens over STOMP (see below + WebSocketConfig).
    @GetMapping("/course/{courseId}")
    public List<ChatMessageDto> history(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long courseId) {
        return chatService.history(courseId, principal.getId());
    }

    @PostMapping("/course/{courseId}/send")
    public ChatMessageDto sendRest(@AuthenticationPrincipal AppUserPrincipal principal,
                                    @PathVariable Long courseId, @RequestBody ChatSendRequest req) {
        return chatService.send(courseId, principal.getId(), req.getContent());
    }

    // STOMP endpoint: client sends to /app/chat.send with a ChatSendRequest{courseId, content}.
    // Broadcast arrives on /topic/course/{courseId}. The sender is taken from the STOMP session's
    // authenticated Principal (set by StompAuthChannelInterceptor from the CONNECT frame's JWT) --
    // any senderId in the payload is ignored so a client can't impersonate another user.
    @MessageMapping("/chat.send")
    public void sendViaWebSocket(@Payload ChatSendRequest req, Principal principal) {
        if (!(principal instanceof AbstractAuthenticationToken auth) || !(auth.getPrincipal() instanceof AppUserPrincipal appUser)) {
            throw new IllegalArgumentException("Unauthenticated chat connection");
        }
        chatService.send(req.getCourseId(), appUser.getId(), req.getContent());
    }
}
