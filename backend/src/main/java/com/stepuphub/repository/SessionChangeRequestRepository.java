package com.stepuphub.repository;

import com.stepuphub.domain.SessionChangeRequest;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SessionChangeRequestRepository extends JpaRepository<SessionChangeRequest, Long> {
    List<SessionChangeRequest> findBySessionIdAndStatus(Long sessionId, SessionChangeRequest.ChangeStatus status);
    List<SessionChangeRequest> findBySessionIdOrderByCreatedAtDesc(Long sessionId);
    List<SessionChangeRequest> findAllByOrderByCreatedAtDesc();
    List<SessionChangeRequest> findBySession_Teacher_IdOrderByCreatedAtDesc(Long teacherId);
    List<SessionChangeRequest> findBySession_Students_IdOrderByCreatedAtDesc(Long studentId);
}
