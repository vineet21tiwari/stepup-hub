package com.stepuphub.dto;

import com.stepuphub.domain.SessionType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

/**
 * Generates one Slot per matching weekday between startDate and repeatUntil, all tagged with the
 * same recurrenceGroupId so they can later be bulk-cancelled as a series. Each weekday in
 * dayWindows carries its own start/end time-of-day (evaluated in UTC), so a teacher's free hours
 * can differ from day to day. classesPerWeek is how many of these days a student must pick when booking.
 */
@Data
public class RecurringSlotRequest {
    @NotNull
    private Long courseId;

    @NotEmpty
    @Valid
    private List<DayWindow> dayWindows;

    @NotNull
    private LocalDate startDate;

    @NotNull
    private LocalDate repeatUntil;

    private Integer capacity = 1;

    private SessionType sessionType = SessionType.ONE_ON_ONE;

    @NotNull
    private Integer classesPerWeek;

    @Data
    public static class DayWindow {
        @NotNull
        private DayOfWeek dayOfWeek;
        @NotNull
        private LocalTime startTime;
        @NotNull
        private LocalTime endTime;
    }
}
