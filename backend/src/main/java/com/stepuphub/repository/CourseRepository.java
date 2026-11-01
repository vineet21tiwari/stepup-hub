package com.stepuphub.repository;

import com.stepuphub.domain.Course;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CourseRepository extends JpaRepository<Course, Long> {
    List<Course> findByActiveTrue();
    List<Course> findByActiveTrueAndFeaturedTrue();
}
