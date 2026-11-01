package com.stepuphub.service;

import com.stepuphub.domain.Course;
import com.stepuphub.domain.Notification;
import com.stepuphub.domain.Role;
import com.stepuphub.domain.Task;
import com.stepuphub.domain.TaskMessage;
import com.stepuphub.domain.User;
import com.stepuphub.dto.TaskDto;
import com.stepuphub.dto.TaskMessageDto;
import com.stepuphub.dto.TaskRequest;
import com.stepuphub.repository.CourseRepository;
import com.stepuphub.repository.TaskMessageRepository;
import com.stepuphub.repository.TaskRepository;
import com.stepuphub.repository.UserRepository;
import com.stepuphub.util.AppTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Admin -> Coordinator task assignment with a deadline, plus a per-task file-sharing message thread
 * (same attachment handling as DirectMessageService, scoped to the task's two participants).
 */
@Service
@RequiredArgsConstructor
public class TaskService {

    private final TaskRepository taskRepository;
    private final TaskMessageRepository taskMessageRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final FileStorageService fileStorageService;
    private final NotificationService notificationService;

    private User requireUser(Long userId) {
        return userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));
    }

    private Task requireTask(Long taskId) {
        return taskRepository.findById(taskId).orElseThrow(() -> new IllegalArgumentException("Task not found"));
    }

    private void requireParticipant(Task task, Long userId) {
        if (!task.getAssignedBy().getId().equals(userId) && !task.getCoordinator().getId().equals(userId)) {
            throw new IllegalArgumentException("You are not part of this task");
        }
    }

    @Transactional
    public TaskDto create(Long adminId, TaskRequest req) {
        User admin = requireUser(adminId);
        if (admin.getRole() != Role.ADMIN) throw new IllegalArgumentException("Only admins can assign tasks");
        User coordinator = userRepository.findById(req.getCoordinatorId())
                .orElseThrow(() -> new IllegalArgumentException("Coordinator not found"));
        if (coordinator.getRole() != Role.COORDINATOR) throw new IllegalArgumentException("User is not a coordinator");

        Task task = new Task();
        task.setTitle(req.getTitle());
        task.setDescription(req.getDescription());
        task.setAssignedBy(admin);
        task.setCoordinator(coordinator);
        task.setDeadline(req.getDeadline());
        if (req.getCourseId() != null) {
            Course course = courseRepository.findById(req.getCourseId())
                    .orElseThrow(() -> new IllegalArgumentException("Course not found"));
            task.setCourse(course);
        }
        Task saved = taskRepository.save(task);

        String deadlineStr = DateTimeFormatter.ofPattern("MMM d, h:mm a").withZone(AppTime.ZONE).format(saved.getDeadline());
        notificationService.notify(coordinator, Notification.NotificationType.GENERAL,
                "New task \"" + saved.getTitle() + "\" — due " + deadlineStr, "TASK:" + saved.getId());

        return TaskDto.from(saved);
    }

    @Transactional
    public TaskDto updateStatus(Long userId, Long taskId, Task.TaskStatus status) {
        Task task = requireTask(taskId);
        requireParticipant(task, userId);
        task.setStatus(status);
        Task saved = taskRepository.save(task);
        notificationService.notify(saved.getAssignedBy(), Notification.NotificationType.GENERAL,
                saved.getCoordinator().getName() + " marked \"" + saved.getTitle() + "\" as " + status.name().toLowerCase().replace('_', ' '),
                "TASK:" + saved.getId());
        return TaskDto.from(saved);
    }

    @Transactional(readOnly = true)
    public List<TaskDto> listForCoordinator(Long coordinatorId) {
        return taskRepository.findByCoordinatorId(coordinatorId).stream().map(TaskDto::from).toList();
    }

    @Transactional(readOnly = true)
    public List<TaskDto> listCreatedByAdmin(Long adminId) {
        return taskRepository.findByAssignedById(adminId).stream().map(TaskDto::from).toList();
    }

    @Transactional
    public TaskMessageDto sendMessage(Long taskId, Long senderId, String content, MultipartFile attachment) {
        Task task = requireTask(taskId);
        requireParticipant(task, senderId);
        User sender = requireUser(senderId);
        boolean hasText = content != null && !content.isBlank();
        boolean hasFile = attachment != null && !attachment.isEmpty();
        if (!hasText && !hasFile) {
            throw new IllegalArgumentException("Message cannot be empty");
        }

        TaskMessage msg = new TaskMessage();
        msg.setTask(task);
        msg.setSender(sender);
        msg.setContent(hasText ? content.trim() : null);
        if (hasFile) {
            msg.setAttachmentUrl(fileStorageService.store("task-attachments", attachment));
            msg.setAttachmentName(attachment.getOriginalFilename());
        }
        msg = taskMessageRepository.save(msg);

        User recipient = sender.getId().equals(task.getAssignedBy().getId()) ? task.getCoordinator() : task.getAssignedBy();
        String preview = hasText ? (content.length() > 80 ? content.substring(0, 80) + "..." : content) : "sent a file";
        notificationService.notify(recipient, Notification.NotificationType.NEW_CHAT_MESSAGE,
                sender.getName() + " on \"" + task.getTitle() + "\": " + preview, "TASK:" + task.getId());

        return TaskMessageDto.from(msg);
    }

    @Transactional(readOnly = true)
    public List<TaskMessageDto> messages(Long taskId, Long userId) {
        Task task = requireTask(taskId);
        requireParticipant(task, userId);
        return taskMessageRepository.findByTaskIdOrderBySentAtAsc(taskId).stream().map(TaskMessageDto::from).toList();
    }
}
