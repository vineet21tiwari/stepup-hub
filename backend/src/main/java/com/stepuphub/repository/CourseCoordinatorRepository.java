package com.stepuphub.repository;

import com.stepuphub.domain.CourseCoordinator;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface CourseCoordinatorRepository extends JpaRepository<CourseCoordinator, Long> {
    List<CourseCoordinator> findByCourseId(Long courseId);
    List<CourseCoordinator> findByCoordinatorId(Long coordinatorId);
    boolean existsByCourseIdAndCoordinatorId(Long courseId, Long coordinatorId);
    Optional<CourseCoordinator> findByCourseIdAndCoordinatorId(Long courseId, Long coordinatorId);
}
