package com.stepuphub.dto;

import lombok.Data;

@Data
public class ChatSendRequest {
    private Long courseId;
    private Long senderId;
    private String content;
}
