package com.stepuphub.repository;

import com.stepuphub.domain.Task;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TaskRepository extends JpaRepository<Task, Long> {
    List<Task> findByCoordinatorId(Long coordinatorId);
    List<Task> findByAssignedById(Long adminId);
}
