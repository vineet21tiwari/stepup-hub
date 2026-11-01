package com.stepuphub.service;

import com.stepuphub.domain.*;
import com.stepuphub.dto.AssignmentDto;
import com.stepuphub.dto.AssignmentRequest;
import com.stepuphub.dto.GradeRequest;
import com.stepuphub.dto.SubmissionDto;
import com.stepuphub.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Assignments per course, posted as a PDF by the course's teacher or an admin, with student submissions
 * and grading by the author (or an admin).
 */
@Service
@RequiredArgsConstructor
public class AssignmentService {

    private final AssignmentRepository assignmentRepository;
    private final AssignmentSubmissionRepository submissionRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final EnrollmentRequestRepository enrollmentRequestRepository;
    private final FileStorageService fileStorageService;
    private final NotificationService notificationService;
    private final CourseAccessService courseAccessService;

    private User requireRole(Long userId, Role role) {
        User u = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));
        if (u.getRole() != role) throw new IllegalArgumentException("Requires role " + role);
        return u;
    }

    @Transactional
    public AssignmentDto createAssignment(Long authorId, AssignmentRequest req, MultipartFile attachment) {
        User author = courseAccessService.requireUser(authorId);
        Course course = courseRepository.findById(req.getCourseId())
                .orElseThrow(() -> new IllegalArgumentException("Course not found"));

        if (!courseAccessService.canManage(course.getId(), author)) {
            throw new IllegalArgumentException("Only an admin or an approved teacher for this course can post assignments");
        }
        requirePdf(attachment);

        Assignment a = new Assignment();
        a.setTitle(req.getTitle());
        a.setDescription(req.getDescription());
        a.setCourse(course);
        a.setTeacher(author);
        a.setDueDate(req.getDueDate());
        a.setAttachmentUrl(fileStorageService.store("assignments", attachment));
        Assignment saved = assignmentRepository.save(a);

        Set<User> students = new LinkedHashSet<>();
        enrollmentRequestRepository.findBySlotCourseIdAndStatus(course.getId(), RequestStatus.APPROVED)
                .forEach(er -> students.add(er.getStudent()));
        students.forEach(student -> notificationService.notify(student, Notification.NotificationType.ASSIGNMENT_POSTED,
                "New assignment \"" + saved.getTitle() + "\" posted for \"" + course.getTitle() + "\"",
                "ASSIGNMENT:" + saved.getId()));

        return AssignmentDto.from(saved);
    }

    // Assignments must be a real PDF: checks the extension and the "%PDF" file signature, not just the
    // client-supplied content type.
    private static void requirePdf(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Attach the assignment as a PDF file");
        }
        String name = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().toLowerCase(Locale.ROOT);
        boolean pdf = name.endsWith(".pdf");
        if (pdf) {
            try (InputStream in = file.getInputStream()) {
                pdf = new String(in.readNBytes(4), StandardCharsets.ISO_8859_1).equals("%PDF");
            } catch (IOException ex) {
                pdf = false;
            }
        }
        if (!pdf) throw new IllegalArgumentException("Assignments must be uploaded as a PDF file");
    }

    @Transactional(readOnly = true)
    public List<AssignmentDto> getAssignmentsForCourse(Long userId, Long courseId) {
        courseAccessService.requireMember(courseId, userId);
        return assignmentRepository.findByCourseIdOrderByDueDateAsc(courseId).stream().map(AssignmentDto::from).toList();
    }

    @Transactional(readOnly = true)
    public AssignmentDto getAssignment(Long userId, Long id) {
        Assignment a = assignmentRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Assignment not found"));
        courseAccessService.requireMember(a.getCourse().getId(), userId);
        return AssignmentDto.from(a);
    }

    @Transactional
    public SubmissionDto submitAssignment(Long studentId, Long assignmentId, MultipartFile file, String textAnswer) {
        User student = requireRole(studentId, Role.STUDENT);
        Assignment assignment = assignmentRepository.findById(assignmentId)
                .orElseThrow(() -> new IllegalArgumentException("Assignment not found"));
        String answer = textAnswer == null ? "" : textAnswer.trim();
        boolean hasFile = file != null && !file.isEmpty();
        if (answer.length() > 4000) {
            throw new IllegalArgumentException("Written answer is too long (max 4000 characters)");
        }

        boolean enrolled = !enrollmentRequestRepository.findByStudentIdAndSlotCourseIdAndStatusIn(
                studentId, assignment.getCourse().getId(), List.of(RequestStatus.APPROVED)).isEmpty();
        if (!enrolled) {
            throw new IllegalArgumentException("You are not enrolled in this course");
        }

        AssignmentSubmission submission = submissionRepository.findByAssignmentIdAndStudentId(assignmentId, studentId)
                .orElseGet(AssignmentSubmission::new);
        if (submission.getStatus() == AssignmentSubmission.SubmissionStatus.GRADED) {
            throw new IllegalArgumentException("This assignment has already been graded and can no longer be resubmitted");
        }

        // Resubmitting keeps the earlier file unless a new one is attached, so a text-only edit is still valid.
        if (!hasFile && answer.isEmpty() && submission.getFileUrl() == null) {
            throw new IllegalArgumentException("Attach a file or write an answer to submit");
        }

        submission.setAssignment(assignment);
        submission.setStudent(student);
        submission.setSubmittedAt(Instant.now());
        submission.setTextAnswer(answer.isEmpty() ? null : answer);
        if (hasFile) {
            submission.setFileUrl(fileStorageService.store("submissions", file));
        }
        submission.setStatus(Instant.now().isAfter(assignment.getDueDate())
                ? AssignmentSubmission.SubmissionStatus.LATE
                : AssignmentSubmission.SubmissionStatus.SUBMITTED);

        AssignmentSubmission saved = submissionRepository.save(submission);

        notificationService.notify(assignment.getTeacher(), Notification.NotificationType.ASSIGNMENT_SUBMITTED,
                student.getName() + " submitted \"" + assignment.getTitle() + "\"",
                "ASSIGNMENT:" + assignment.getId());

        return SubmissionDto.from(saved);
    }

    // The assignment's author (teacher or admin) or any admin may review/grade its submissions.
    private Assignment requireManagedAssignment(Long userId, Long assignmentId) {
        Assignment assignment = assignmentRepository.findById(assignmentId)
                .orElseThrow(() -> new IllegalArgumentException("Assignment not found"));
        User user = courseAccessService.requireUser(userId);
        if (user.getRole() != Role.ADMIN && !assignment.getTeacher().getId().equals(userId)) {
            throw new IllegalArgumentException("Not your assignment");
        }
        return assignment;
    }

    @Transactional(readOnly = true)
    public List<SubmissionDto> listSubmissions(Long userId, Long assignmentId) {
        requireManagedAssignment(userId, assignmentId);
        return submissionRepository.findByAssignmentId(assignmentId).stream().map(SubmissionDto::from).toList();
    }

    @Transactional(readOnly = true)
    public SubmissionDto mySubmission(Long studentId, Long assignmentId) {
        return submissionRepository.findByAssignmentIdAndStudentId(assignmentId, studentId)
                .map(SubmissionDto::from)
                .orElse(null);
    }

    @Transactional
    public SubmissionDto gradeSubmission(Long userId, Long assignmentId, Long submissionId, GradeRequest req) {
        requireManagedAssignment(userId, assignmentId);
        AssignmentSubmission submission = submissionRepository.findById(submissionId)
                .orElseThrow(() -> new IllegalArgumentException("Submission not found"));
        if (!submission.getAssignment().getId().equals(assignmentId)) {
            throw new IllegalArgumentException("Submission does not belong to this assignment");
        }
        submission.setGrade(req.getGrade());
        submission.setFeedback(req.getFeedback());
        submission.setStatus(AssignmentSubmission.SubmissionStatus.GRADED);
        AssignmentSubmission saved = submissionRepository.save(submission);

        notificationService.notify(submission.getStudent(), Notification.NotificationType.ASSIGNMENT_GRADED,
                "Your submission for \"" + submission.getAssignment().getTitle() + "\" was graded: " + req.getGrade(),
                "ASSIGNMENT:" + assignmentId);

        return SubmissionDto.from(saved);
    }
}
