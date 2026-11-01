package com.stepuphub.dto;

import com.stepuphub.domain.Slot;

import java.time.Instant;

public record SlotDto(Long id, Long teacherId, String teacherName, Long courseId, String courseTitle,
                       Instant startTime, Instant endTime, int capacity, int bookedCount, boolean full,
                       boolean cancelled, String recurrenceGroupId, String sessionType, int classesPerWeek) {
    public static SlotDto from(Slot s) {
        return new SlotDto(s.getId(), s.getTeacher().getId(), s.getTeacher().getName(),
                s.getCourse().getId(), s.getCourse().getTitle(),
                s.getStartTime(), s.getEndTime(), s.getCapacity(), s.getBookedCount(), s.isFull(), s.isCancelled(),
                s.getRecurrenceGroupId(), s.getSessionType().name(), s.getClassesPerWeek());
    }
}
