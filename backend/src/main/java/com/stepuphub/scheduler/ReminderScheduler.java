package com.stepuphub.scheduler;

import com.stepuphub.domain.ClassSession;
import com.stepuphub.domain.Notification;
import com.stepuphub.repository.ClassSessionRepository;
import com.stepuphub.repository.CourseCoordinatorRepository;
import com.stepuphub.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Every minute, looks for sessions starting within the configured reminder window
 * (default 30 minutes) that haven't been reminded yet, and notifies the teacher,
 * every enrolled student, and the coordinator (if assigned).
 */
@Component
@RequiredArgsConstructor
public class ReminderScheduler {

    private final ClassSessionRepository classSessionRepository;
    private final CourseCoordinatorRepository courseCoordinatorRepository;
    private final NotificationService notificationService;

    @Value("${app.reminders.minutes-before-class:30}")
    private int minutesBefore;

    @Scheduled(fixedRate = 60_000)
    @Transactional
    public void sendUpcomingClassReminders() {
        Instant now = Instant.now();
        Instant windowEnd = now.plus(minutesBefore, ChronoUnit.MINUTES);

        List<ClassSession> upcoming = classSessionRepository.findByReminderSentFalseAndScheduledStartBetween(now, windowEnd);
        for (ClassSession session : upcoming) {
            if (session.getStatus() != ClassSession.SessionStatus.SCHEDULED) continue;

            String msg = "\"" + session.getCourse().getTitle() + "\" starts at " + session.getScheduledStart();
            notificationService.notify(session.getTeacher(), Notification.NotificationType.CLASS_REMINDER, msg, "SESSION:" + session.getId());
            courseCoordinatorRepository.findByCourseId(session.getCourse().getId())
                    .forEach(cc -> notificationService.notify(cc.getCoordinator(), Notification.NotificationType.CLASS_REMINDER, msg, "SESSION:" + session.getId()));
            session.getStudents().forEach(student ->
                    notificationService.notify(student, Notification.NotificationType.CLASS_REMINDER, msg, "SESSION:" + session.getId()));

            session.setReminderSent(true);
            classSessionRepository.save(session);
        }
    }
}
