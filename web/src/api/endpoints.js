import client from "./client";

export const AuthApi = {
  // resumeFile is optional (teachers only) — switches to multipart when provided.
  signup: (payload, resumeFile) => {
    if (resumeFile) {
      const form = new FormData();
      form.append("data", new Blob([JSON.stringify(payload)], { type: "application/json" }));
      form.append("resume", resumeFile);
      return client.post("/api/auth/signup", form).then((r) => r.data);
    }
    return client.post("/api/auth/signup", payload).then((r) => r.data);
  },
  login: (payload) => client.post("/api/auth/login", payload).then((r) => r.data),
  // TEMPORARY: no OTP/email verification yet, see backend AuthService.resetPassword.
  forgotPassword: (payload) => client.post("/api/auth/forgot-password", payload).then((r) => r.data),
};

export const UserApi = {
  me: () => client.get("/api/users/me").then((r) => r.data),
  // Omit role to get every user, regardless of role — used by the admin Users page.
  byRole: (role) => client.get("/api/users", { params: { role } }).then((r) => r.data),
  update: (id, payload) => client.put(`/api/users/${id}`, payload).then((r) => r.data),
  // "Removing" a user is a reversible deactivate (blocks login, hides them from listings), not a real delete.
  deactivate: (id) => client.post(`/api/users/${id}/deactivate`).then((r) => r.data),
  reactivate: (id) => client.post(`/api/users/${id}/reactivate`).then((r) => r.data),
  // Admin-only: provisions an Admin or Coordinator account directly (students/teachers self-signup instead).
  create: (payload) => client.post("/api/users", payload).then((r) => r.data),
  // Admin-only: generates a new temporary password for the user, returned once — never their actual password.
  resetPassword: (id) => client.post(`/api/users/${id}/reset-password`).then((r) => r.data),
};

export const CourseApi = {
  list: () => client.get("/api/courses").then((r) => r.data),
  get: (id) => client.get(`/api/courses/${id}`).then((r) => r.data),
  teachersForCourse: (id) => client.get(`/api/courses/${id}/teachers`).then((r) => r.data),
  // Course-level coordinator assignment (covers every class in the course).
  coordinatorsForCourse: (id) => client.get(`/api/courses/${id}/coordinators`).then((r) => r.data),
  assignCoordinator: (courseId, coordinatorId) =>
    client.post(`/api/courses/${courseId}/coordinators/${coordinatorId}`).then((r) => r.data),
  unassignCoordinator: (courseId, coordinatorId) =>
    client.delete(`/api/courses/${courseId}/coordinators/${coordinatorId}`).then((r) => r.data),
  // curriculumFile is optional — a PDF brochure students can view from the course page.
  create: (payload, curriculumFile) => {
    const form = new FormData();
    form.append("data", new Blob([JSON.stringify(payload)], { type: "application/json" }));
    if (curriculumFile) form.append("curriculum", curriculumFile);
    return client.post("/api/courses", form).then((r) => r.data);
  },
  update: (id, payload, curriculumFile) => {
    const form = new FormData();
    form.append("data", new Blob([JSON.stringify(payload)], { type: "application/json" }));
    if (curriculumFile) form.append("curriculum", curriculumFile);
    return client.put(`/api/courses/${id}`, form).then((r) => r.data);
  },
  deactivate: (id) => client.delete(`/api/courses/${id}`).then((r) => r.data),
};

export const TeacherApi = {
  approvedTeachers: () => client.get("/api/teachers").then((r) => r.data),
  // videoFile is optional — an intro clip students can watch when picking a teacher for this course.
  apply: (courseId, videoFile) => {
    if (videoFile) {
      const form = new FormData();
      form.append("video", videoFile);
      return client.post(`/api/teachers/applications/${courseId}`, form).then((r) => r.data);
    }
    return client.post(`/api/teachers/applications/${courseId}`).then((r) => r.data);
  },
  // Add or replace the intro video for an application already submitted (e.g. skipped at apply time).
  addApplicationVideo: (applicationId, videoFile) => {
    const form = new FormData();
    form.append("video", videoFile);
    return client.post(`/api/teachers/applications/${applicationId}/video`, form).then((r) => r.data);
  },
  myApplications: () => client.get("/api/teachers/applications/mine").then((r) => r.data),
  // Admin use: every course application (any status) for an arbitrary teacher.
  applicationsForTeacher: (teacherId) => client.get(`/api/teachers/${teacherId}/applications`).then((r) => r.data),
  // Teacher withdraws their own still-pending application.
  cancelApplication: (applicationId) => client.delete(`/api/teachers/applications/${applicationId}`).then((r) => r.data),
  pendingApplications: () => client.get("/api/teachers/applications/pending").then((r) => r.data),
  decideApplication: (applicationId, approve, note) =>
    client.post(`/api/teachers/applications/${applicationId}/decide`, { approve, note }).then((r) => r.data),
  createSlot: (payload) => client.post("/api/teachers/slots", payload).then((r) => r.data),
  // A teacher may only have one active slot per course — edit it instead of creating a new one.
  updateSlot: (slotId, payload) => client.put(`/api/teachers/slots/${slotId}`, payload).then((r) => r.data),
  // Generates one Slot per matching weekday between payload.startDate and payload.repeatUntil, each
  // using that weekday's own time window (payload.dayWindows), all sharing one recurrenceGroupId server-side.
  createRecurringSlots: (payload) => client.post("/api/teachers/slots/recurring", payload).then((r) => r.data),
  mySlots: () => client.get("/api/teachers/slots/mine").then((r) => r.data),
  slotsForTeacherAndCourse: (teacherId, courseId) =>
    client.get(`/api/teachers/${teacherId}/courses/${courseId}/slots`).then((r) => r.data),
  // The teacher's busy/blocked windows for one day (YYYY-MM-DD), across ALL their courses.
  busyTimes: (teacherId, dateStr) =>
    client.get(`/api/teachers/${teacherId}/busy`, { params: { date: dateStr } }).then((r) => r.data),
  cancelSlot: (slotId) => client.delete(`/api/teachers/slots/${slotId}`).then((r) => r.data),
  cancelSlotSeries: (recurrenceGroupId) =>
    client.delete(`/api/teachers/slots/series/${encodeURIComponent(recurrenceGroupId)}`).then((r) => r.data),
};

export const CoordinatorApi = {
  // Which courses a coordinator is assigned to — used by admin's assignment view and the
  // coordinator's own "My courses" dashboard section.
  coursesFor: (coordinatorId) => client.get(`/api/coordinators/${coordinatorId}/courses`).then((r) => r.data),
};

export const EnrollmentApi = {
  book: (slotId) => client.post(`/api/enrollment-requests/book/${slotId}`).then((r) => r.data),
  // Books a whole weekly commitment at once: one chosen Slot id per weekday required by the plan.
  bookRecurring: (slotIds) => client.post("/api/enrollment-requests/book-recurring", slotIds).then((r) => r.data),
  mine: () => client.get("/api/enrollment-requests/mine").then((r) => r.data),
  // Student withdraws their own still-pending request (cancels the whole weekly batch if part of one).
  cancel: (id) => client.delete(`/api/enrollment-requests/${id}`).then((r) => r.data),
  pendingForTeacher: () => client.get("/api/enrollment-requests/pending-for-teacher").then((r) => r.data),
  pendingForAdmin: () => client.get("/api/enrollment-requests/pending-for-admin").then((r) => r.data),
  teacherDecide: (id, approve, note) =>
    client.post(`/api/enrollment-requests/${id}/teacher-decide`, { approve, note }).then((r) => r.data),
  adminDecide: (id, approve, note) =>
    client.post(`/api/enrollment-requests/${id}/admin-decide`, { approve, note }).then((r) => r.data),
};

export const SessionApi = {
  mine: () => client.get("/api/sessions/mine").then((r) => r.data),
  get: (id) => client.get(`/api/sessions/${id}`).then((r) => r.data),
  // The current user's classes for one course.
  forCourse: (courseId) => client.get(`/api/sessions/course/${courseId}`).then((r) => r.data),
  // Teacher only: attach (or replace) the Zoom / Google Meet link that starts this class.
  setMeetingLink: (id, meetingLink) => client.put(`/api/sessions/${id}/meeting`, { meetingLink }).then((r) => r.data),
  clearMeetingLink: (id) => client.delete(`/api/sessions/${id}/meeting`).then((r) => r.data),
  // Coordinator (assigned to the course) or admin only.
  markAttendance: (id, payload) => client.put(`/api/sessions/${id}/attendance`, payload).then((r) => r.data),
};

// What the current user may see/do on a course page: { member, canManage }.
export const CourseAccessApi = {
  get: (courseId) => client.get(`/api/course-access/${courseId}`).then((r) => r.data),
};

// Course feed posts: any member can post and like (no comments). Announcements/assignments are separate APIs.
export const PostApi = {
  forCourse: (courseId) => client.get(`/api/posts/course/${courseId}`).then((r) => r.data),
  create: (courseId, content) => client.post(`/api/posts/course/${courseId}`, { content }).then((r) => r.data),
  toggleLike: (id) => client.post(`/api/posts/${id}/like`).then((r) => r.data),
  delete: (id) => client.delete(`/api/posts/${id}`).then((r) => r.data),
};

// Assignments are PDFs posted by the course teacher or an admin.
export const AssignmentApi = {
  create: (payload, pdfFile) => {
    const form = new FormData();
    form.append("data", new Blob([JSON.stringify(payload)], { type: "application/json" }));
    form.append("attachment", pdfFile);
    return client.post("/api/assignments", form).then((r) => r.data);
  },
  forCourse: (courseId) => client.get(`/api/assignments/course/${courseId}`).then((r) => r.data),
  get: (id) => client.get(`/api/assignments/${id}`).then((r) => r.data),
  // Student: submit (or resubmit until graded) a file and/or written answer.
  submit: (id, file, textAnswer) => {
    const form = new FormData();
    if (file) form.append("file", file);
    if (textAnswer) form.append("textAnswer", textAnswer);
    return client.post(`/api/assignments/${id}/submit`, form).then((r) => r.data);
  },
  // The current student's own submission, or "" (empty body) when they haven't submitted yet.
  mySubmission: (id) => client.get(`/api/assignments/${id}/submissions/mine`).then((r) => r.data || null),
  // Assignment author or admin: every student's submission, and grading.
  submissions: (id) => client.get(`/api/assignments/${id}/submissions`).then((r) => r.data),
  grade: (id, submissionId, grade, feedback) =>
    client.post(`/api/assignments/${id}/submissions/${submissionId}/grade`, { grade, feedback }).then((r) => r.data),
};

// Chat is scoped to the whole course (one thread covering every class in it), not one session.
// Private Admin<->Coordinator messaging, with an optional file attachment (image/PDF) per message.
export const DirectMessageApi = {
  history: (otherUserId) => client.get(`/api/direct-messages/${otherUserId}`).then((r) => r.data),
  send: (otherUserId, content, file) => {
    const form = new FormData();
    if (content) form.append("content", content);
    if (file) form.append("attachment", file);
    return client.post(`/api/direct-messages/${otherUserId}/send`, form).then((r) => r.data);
  },
};

// Admin -> Coordinator tasks with a deadline, plus a per-task file-sharing message thread.
export const TaskApi = {
  create: (payload) => client.post("/api/tasks", payload).then((r) => r.data),
  // Role-aware: coordinator sees tasks assigned to them, admin sees tasks they created.
  mine: () => client.get("/api/tasks/mine").then((r) => r.data),
  updateStatus: (id, status) => client.put(`/api/tasks/${id}/status`, { status }).then((r) => r.data),
  messages: (id) => client.get(`/api/tasks/${id}/messages`).then((r) => r.data),
  sendMessage: (id, content, file) => {
    const form = new FormData();
    if (content) form.append("content", content);
    if (file) form.append("attachment", file);
    return client.post(`/api/tasks/${id}/messages/send`, form).then((r) => r.data);
  },
};

export const ChatApi = {
  history: (courseId) => client.get(`/api/chat/course/${courseId}`).then((r) => r.data),
  send: (courseId, content) =>
    client.post(`/api/chat/course/${courseId}/send`, { content }).then((r) => r.data),
};

export const NotificationApi = {
  list: () => client.get("/api/notifications").then((r) => r.data),
  markRead: (id) => client.post(`/api/notifications/${id}/read`).then((r) => r.data),
};

export const AnnouncementApi = {
  create: (payload) => client.post("/api/announcements", payload).then((r) => r.data),
  all: () => client.get("/api/announcements").then((r) => r.data),
  get: (id) => client.get(`/api/announcements/${id}`).then((r) => r.data),
  // Only title/message are actually changed server-side — scope/course are fixed at creation time.
  update: (id, payload) => client.put(`/api/announcements/${id}`, payload).then((r) => r.data),
  delete: (id) => client.delete(`/api/announcements/${id}`).then((r) => r.data),
  global: () => client.get("/api/announcements/global").then((r) => r.data),
  forCourse: (courseId) => client.get(`/api/announcements/course/${courseId}`).then((r) => r.data),
};

// Public Home/About/Contact pages and testimonials — admin-editable, publicly readable.
export const SiteApi = {
  getPage: (key) => client.get(`/api/site/pages/${key}`).then((r) => r.data),
  updatePage: (key, payload, imageFile) => {
    const form = new FormData();
    form.append("data", new Blob([JSON.stringify(payload)], { type: "application/json" }));
    if (imageFile) form.append("image", imageFile);
    return client.put(`/api/site/pages/${key}`, form).then((r) => r.data);
  },
  publishedTestimonials: () => client.get("/api/site/testimonials").then((r) => r.data),
  allTestimonials: () => client.get("/api/site/testimonials/all").then((r) => r.data),
  createTestimonial: (payload, photoFile) => {
    const form = new FormData();
    form.append("data", new Blob([JSON.stringify(payload)], { type: "application/json" }));
    if (photoFile) form.append("photo", photoFile);
    return client.post("/api/site/testimonials", form).then((r) => r.data);
  },
  updateTestimonial: (id, payload, photoFile) => {
    const form = new FormData();
    form.append("data", new Blob([JSON.stringify(payload)], { type: "application/json" }));
    if (photoFile) form.append("photo", photoFile);
    return client.put(`/api/site/testimonials/${id}`, form).then((r) => r.data);
  },
  deleteTestimonial: (id) => client.delete(`/api/site/testimonials/${id}`).then((r) => r.data),
};
