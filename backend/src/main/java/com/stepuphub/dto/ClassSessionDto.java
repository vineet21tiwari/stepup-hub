package com.stepuphub.dto;

import com.stepuphub.domain.ClassSession;
import com.stepuphub.domain.SessionType;
import com.stepuphub.util.MeetingLinks;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

/**
 * meetingLink is only populated for viewers allowed to open it right now (the class teacher and admins
 * always; students/coordinators only from joinOpensAt until the class ends) — see ClassSessionService.
 * hasMeetingLink tells everyone else that a link exists and will unlock at joinOpensAt.
 * Coordinators are assigned at the course level now (see CourseController's /coordinators endpoints),
 * not per session, so this DTO no longer carries a single coordinator field.
 * actualStart/actualEnd/durationMinutes/teacherPresent/attendance are coordinator-recorded attendance
 * (see ClassSessionService.markAttendance) — visible to every course member, not viewer-restricted.
 */
public record ClassSessionDto(Long id, Long courseId, String courseTitle, Long teacherId, String teacherName,
                               Instant scheduledStart, Instant scheduledEnd, String status,
                               String sessionType, List<UserSummaryDto> students,
                               String meetingLink, String meetingProvider, boolean hasMeetingLink,
                               Instant joinOpensAt, Instant actualStart, Instant actualEnd,
                               Long durationMinutes, Boolean teacherPresent, List<StudentAttendanceDto> attendance) {
    public static ClassSessionDto from(ClassSession s, String visibleMeetingLink, Instant joinOpensAt,
                                        List<StudentAttendanceDto> attendance) {
        Long durationMinutes = (s.getActualStart() != null && s.getActualEnd() != null)
                ? Duration.between(s.getActualStart(), s.getActualEnd()).toMinutes() : null;
        return new ClassSessionDto(
                s.getId(), s.getCourse().getId(), s.getCourse().getTitle(),
                s.getTeacher().getId(), s.getTeacher().getName(),
                s.getScheduledStart(), s.getScheduledEnd(), s.getStatus().name(),
                (s.getSlot() != null ? s.getSlot().getSessionType() : SessionType.ONE_ON_ONE).name(),
                s.getStudents().stream().map(UserSummaryDto::from).collect(Collectors.toList()),
                visibleMeetingLink, MeetingLinks.providerOf(s.getMeetingLink()),
                s.getMeetingLink() != null && !s.getMeetingLink().isBlank(),
                joinOpensAt, s.getActualStart(), s.getActualEnd(), durationMinutes, s.getTeacherPresent(), attendance
        );
    }
}
