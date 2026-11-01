package com.stepuphub.util;

import java.time.ZoneId;

// The platform serves students/teachers in India (no daylight saving to worry about), so every
// "which calendar day/hour is this Instant" question and every teacher-entered wall-clock time
// (e.g. a weekly-availability window's "9 AM") is interpreted in this single fixed zone rather
// than UTC — otherwise a teacher typing "9 AM" would be stored as 9 AM UTC and redisplay as
// 2:30 PM IST.
public final class AppTime {
    public static final ZoneId ZONE = ZoneId.of("Asia/Kolkata");

    private AppTime() {
    }
}
