package com.stepuphub.repository;

import com.stepuphub.domain.Slot;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface SlotRepository extends JpaRepository<Slot, Long> {
    List<Slot> findByTeacherIdAndCourseIdAndCancelledFalse(Long teacherId, Long courseId);
    Optional<Slot> findFirstByTeacherIdAndCourseIdAndCancelledFalse(Long teacherId, Long courseId);
    List<Slot> findByTeacherIdAndCancelledFalse(Long teacherId);
    List<Slot> findByCourseIdAndCancelledFalse(Long courseId);
    List<Slot> findByStartTimeBetween(Instant from, Instant to);
    List<Slot> findByRecurrenceGroupIdAndCancelledFalse(String recurrenceGroupId);
}
