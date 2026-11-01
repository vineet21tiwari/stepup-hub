package com.stepuphub.repository;

import com.stepuphub.domain.ClassSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;

public interface ClassSessionRepository extends JpaRepository<ClassSession, Long> {
    List<ClassSession> findByTeacherId(Long teacherId);
    List<ClassSession> findByStudents_Id(Long studentId);
    List<ClassSession> findByCourseId(Long courseId);
    // A coordinator's classes are every session under the courses they're assigned to (course-level
    // assignment — see CourseCoordinatorService), not a per-session field anymore.
    List<ClassSession> findByCourseIdIn(List<Long> courseIds);
    // Every occurrence generated from the same recurring-availability request (see Slot.recurrenceGroupId) —
    // used so a meeting link the teacher adds once applies to the whole series, not just one occurrence.
    List<ClassSession> findBySlot_RecurrenceGroupId(String recurrenceGroupId);
    List<ClassSession> findByReminderSentFalseAndScheduledStartBetween(Instant from, Instant to);
    // Used to compute a teacher's busy/blocked time across ALL their courses for a given day.
    List<ClassSession> findByTeacherIdAndStatusNotAndScheduledStartBetween(
            Long teacherId, ClassSession.SessionStatus status, Instant from, Instant to);
}
