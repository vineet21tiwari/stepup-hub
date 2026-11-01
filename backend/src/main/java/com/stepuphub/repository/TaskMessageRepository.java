package com.stepuphub.repository;

import com.stepuphub.domain.TaskMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TaskMessageRepository extends JpaRepository<TaskMessage, Long> {
    List<TaskMessage> findByTaskIdOrderBySentAtAsc(Long taskId);
}
