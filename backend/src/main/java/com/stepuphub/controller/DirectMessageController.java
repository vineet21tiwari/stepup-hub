package com.stepuphub.controller;

import com.stepuphub.dto.DirectMessageDto;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.DirectMessageService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

// Private Admin<->Coordinator messaging (see DirectMessageService.requirePairing). Sends go over REST
// (so an optional file attachment can ride along) and are broadcast server-side over STOMP for
// realtime delivery to whichever side has the thread open — no separate STOMP send path needed.
@RestController
@RequestMapping("/api/direct-messages")
@RequiredArgsConstructor
public class DirectMessageController {

    private final DirectMessageService directMessageService;

    @GetMapping("/{otherUserId}")
    public List<DirectMessageDto> history(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long otherUserId) {
        return directMessageService.history(principal.getId(), otherUserId);
    }

    @PostMapping("/{otherUserId}/send")
    public DirectMessageDto send(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long otherUserId,
                                  @RequestParam(required = false) String content,
                                  @RequestParam(required = false) MultipartFile attachment) {
        return directMessageService.send(principal.getId(), otherUserId, content, attachment);
    }
}
