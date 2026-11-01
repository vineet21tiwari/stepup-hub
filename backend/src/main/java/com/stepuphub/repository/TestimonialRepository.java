package com.stepuphub.repository;

import com.stepuphub.domain.Testimonial;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TestimonialRepository extends JpaRepository<Testimonial, Long> {
    List<Testimonial> findByPublishedTrueOrderByDisplayOrderAscCreatedAtDesc();
    List<Testimonial> findAllByOrderByDisplayOrderAscCreatedAtDesc();
}