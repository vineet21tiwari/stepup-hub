package com.stepuphub.repository;

import com.stepuphub.domain.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    List<ChatMessage> findByCourseIdOrderBySentAtAsc(Long courseId);
}
