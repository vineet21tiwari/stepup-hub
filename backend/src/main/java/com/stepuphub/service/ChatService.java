package com.stepuphub.service;

import com.stepuphub.domain.ApprovalStatus;
import com.stepuphub.domain.ChatMessage;
import com.stepuphub.domain.Course;
import com.stepuphub.domain.RequestStatus;
import com.stepuphub.domain.User;
import com.stepuphub.dto.ChatMessageDto;
import com.stepuphub.repository.ChatMessageRepository;
import com.stepuphub.repository.CourseCoordinatorRepository;
import com.stepuphub.repository.CourseRepository;
import com.stepuphub.repository.EnrollmentRequestRepository;
import com.stepuphub.repository.TeacherCourseEnrollmentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * One chat thread per course (covers every class in it), not one per class session — a student and
 * teacher only need a single place to talk regardless of which of the course's classes it's about.
 */
@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatMessageRepository chatMessageRepository;
    private final CourseRepository courseRepository;
    private final CourseAccessService courseAccessService;
    private final TeacherCourseEnrollmentRepository teacherCourseEnrollmentRepository;
    private final EnrollmentRequestRepository enrollmentRequestRepository;
    private final CourseCoordinatorRepository courseCoordinatorRepository;
    private final NotificationService notificationService;
    private final SimpMessagingTemplate messagingTemplate;

    @Transactional
    public ChatMessageDto send(Long courseId, Long senderId, String content) {
        if (content == null || content.isBlank()) {
            throw new IllegalArgumentException("Message cannot be empty");
        }
        User sender = courseAccessService.requireMember(courseId, senderId);
        Course course = courseRepository.findById(courseId).orElseThrow(() -> new IllegalArgumentException("Course not found"));

        ChatMessage msg = new ChatMessage();
        msg.setCourse(course);
        msg.setSender(sender);
        msg.setContent(content.trim());
        msg = chatMessageRepository.save(msg);

        ChatMessageDto dto = ChatMessageDto.from(msg);
        messagingTemplate.convertAndSend("/topic/course/" + courseId, dto);

        notifyMembersExceptSender(course, sender, dto);

        return dto;
    }

    // Everyone with access to this course's classroom (see CourseAccessService): approved teachers,
    // students with an approved booking, and coordinators assigned to the course.
    private Set<User> courseMembers(Long courseId) {
        Set<User> members = new LinkedHashSet<>();
        teacherCourseEnrollmentRepository.findByCourseIdAndStatus(courseId, ApprovalStatus.APPROVED)
                .forEach(e -> members.add(e.getTeacher()));
        enrollmentRequestRepository.findBySlotCourseIdAndStatus(courseId, RequestStatus.APPROVED)
                .forEach(r -> members.add(r.getStudent()));
        courseCoordinatorRepository.findByCourseId(courseId).forEach(cc -> members.add(cc.getCoordinator()));
        return members;
    }

    private void notifyMembersExceptSender(Course course, User sender, ChatMessageDto dto) {
        String preview = dto.content().length() > 80 ? dto.content().substring(0, 80) + "..." : dto.content();
        String text = sender.getName() + " in \"" + course.getTitle() + "\": " + preview;
        String ref = "COURSE:" + course.getId();

        courseMembers(course.getId()).forEach(member -> {
            if (!member.getId().equals(sender.getId())) {
                notificationService.notify(member, com.stepuphub.domain.Notification.NotificationType.NEW_CHAT_MESSAGE, text, ref);
            }
        });
    }

    @Transactional(readOnly = true)
    public List<ChatMessageDto> history(Long courseId, Long requestingUserId) {
        courseAccessService.requireMember(courseId, requestingUserId);
        return chatMessageRepository.findByCourseIdOrderBySentAtAsc(courseId)
                .stream().map(ChatMessageDto::from).toList();
    }
}
