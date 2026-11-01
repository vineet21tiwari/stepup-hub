package com.stepuphub.repository;

import com.stepuphub.domain.DirectMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface DirectMessageRepository extends JpaRepository<DirectMessage, Long> {

    // The conversation between two users, either direction, oldest first.
    @Query("select m from DirectMessage m where (m.sender.id = :a and m.recipient.id = :b) " +
            "or (m.sender.id = :b and m.recipient.id = :a) order by m.sentAt asc")
    List<DirectMessage> findConversation(@Param("a") Long userIdA, @Param("b") Long userIdB);
}
