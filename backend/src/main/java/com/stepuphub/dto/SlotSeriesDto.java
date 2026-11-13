package com.stepuphub.dto;

import java.time.Instant;

/** Admin overview row for one recurring slot series (all active slots sharing a recurrenceGroupId). */
public record SlotSeriesDto(String recurrenceGroupId, Long teacherId, String teacherName, Long courseId, String courseTitle,
                            String sessionType, int totalSlots, int bookedSlots, Instant firstStart, Instant lastStart) {}
