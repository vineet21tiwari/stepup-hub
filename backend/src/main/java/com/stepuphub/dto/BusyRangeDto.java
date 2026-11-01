package com.stepuphub.dto;

import java.time.Instant;

// A teacher-busy window (from a scheduled class in ANY course), used to grey out
// already-occupied time when a student is browsing that teacher's availability.
public record BusyRangeDto(Instant start, Instant end) {
}
