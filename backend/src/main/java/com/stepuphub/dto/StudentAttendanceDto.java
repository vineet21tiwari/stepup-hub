package com.stepuphub.dto;

import com.stepuphub.domain.StudentAttendance;

public record StudentAttendanceDto(Long studentId, String studentName, boolean present) {
    public static StudentAttendanceDto from(StudentAttendance a) {
        return new StudentAttendanceDto(a.getStudent().getId(), a.getStudent().getName(), a.isPresent());
    }
}
