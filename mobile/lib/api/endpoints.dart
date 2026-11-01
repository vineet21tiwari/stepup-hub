import 'api_client.dart';

Map<String, dynamic> _m(dynamic res) => Map<String, dynamic>.from(res as Map);
List<dynamic> _l(dynamic res) => res == null ? [] : List<dynamic>.from(res as List);

class AuthApi {
  // resumePath is optional (teachers only) — switches to multipart when provided.
  static Future<Map<String, dynamic>> signup(Map<String, dynamic> payload, {String? resumePath}) async {
    if (resumePath != null) {
      final res = await ApiClient.multipart(
        'POST',
        '/api/auth/signup',
        jsonParts: {'data': payload},
        files: [ApiFile('resume', resumePath)],
      );
      return _m(res);
    }
    return _m(await ApiClient.post('/api/auth/signup', payload));
  }

  static Future<Map<String, dynamic>> login(String email, String password) =>
      ApiClient.post('/api/auth/login', {'email': email, 'password': password}).then(_m);

  static Future<void> forgotPassword(String email, String newPassword, String confirmPassword) =>
      ApiClient.post('/api/auth/forgot-password', {
        'email': email,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      });
}

class UserApi {
  static Future<Map<String, dynamic>> me() => ApiClient.get('/api/users/me').then(_m);

  static Future<Map<String, dynamic>> uploadResume(String path) async {
    final res = await ApiClient.multipart('POST', '/api/users/me/resume', files: [ApiFile('resume', path)]);
    return _m(res);
  }

  // Omit role to get every user.
  static Future<List<dynamic>> byRole([String? role]) =>
      ApiClient.get('/api/users', query: role == null ? null : {'role': role}).then(_l);

  static Future<Map<String, dynamic>> update(int id, Map<String, dynamic> payload) =>
      ApiClient.put('/api/users/$id', payload).then(_m);

  static Future<Map<String, dynamic>> deactivate(int id) => ApiClient.post('/api/users/$id/deactivate').then(_m);
  static Future<Map<String, dynamic>> reactivate(int id) => ApiClient.post('/api/users/$id/reactivate').then(_m);

  // Admin-only: provisions an Admin or Coordinator account directly.
  static Future<Map<String, dynamic>> create(Map<String, dynamic> payload) =>
      ApiClient.post('/api/users', payload).then(_m);

  // Admin-only: generates a new temporary password, returned once.
  static Future<Map<String, dynamic>> resetPassword(int id) =>
      ApiClient.post('/api/users/$id/reset-password').then(_m);
}

class CourseApi {
  static Future<List<dynamic>> list() => ApiClient.get('/api/courses').then(_l);
  static Future<Map<String, dynamic>> get(int id) => ApiClient.get('/api/courses/$id').then(_m);
  static Future<List<dynamic>> teachersForCourse(int courseId) =>
      ApiClient.get('/api/courses/$courseId/teachers').then(_l);

  static Future<Map<String, dynamic>> create(Map<String, dynamic> payload, {String? curriculumPath}) async {
    final res = await ApiClient.multipart(
      'POST',
      '/api/courses',
      jsonParts: {'data': payload},
      files: curriculumPath == null ? [] : [ApiFile('curriculum', curriculumPath)],
    );
    return _m(res);
  }

  static Future<Map<String, dynamic>> update(int id, Map<String, dynamic> payload, {String? curriculumPath}) async {
    final res = await ApiClient.multipart(
      'PUT',
      '/api/courses/$id',
      jsonParts: {'data': payload},
      files: curriculumPath == null ? [] : [ApiFile('curriculum', curriculumPath)],
    );
    return _m(res);
  }

  static Future<void> deactivate(int id) => ApiClient.delete('/api/courses/$id');

  // Course-level coordinator assignment (covers every class in the course).
  static Future<List<dynamic>> coordinatorsForCourse(int id) =>
      ApiClient.get('/api/courses/$id/coordinators').then(_l);
  static Future<void> assignCoordinator(int courseId, int coordinatorId) =>
      ApiClient.post('/api/courses/$courseId/coordinators/$coordinatorId');
  static Future<void> unassignCoordinator(int courseId, int coordinatorId) =>
      ApiClient.delete('/api/courses/$courseId/coordinators/$coordinatorId');
}

class CoordinatorApi {
  static Future<List<dynamic>> coursesFor(int coordinatorId) =>
      ApiClient.get('/api/coordinators/$coordinatorId/courses').then(_l);
}

class TeacherApi {
  static Future<List<dynamic>> approvedTeachers() => ApiClient.get('/api/teachers').then(_l);

  static Future<Map<String, dynamic>> apply(int courseId, {String? videoPath}) async {
    if (videoPath != null) {
      final res = await ApiClient.multipart('POST', '/api/teachers/applications/$courseId',
          files: [ApiFile('video', videoPath)]);
      return _m(res);
    }
    return _m(await ApiClient.post('/api/teachers/applications/$courseId'));
  }

  static Future<Map<String, dynamic>> addApplicationVideo(int applicationId, String videoPath) async {
    final res = await ApiClient.multipart('POST', '/api/teachers/applications/$applicationId/video',
        files: [ApiFile('video', videoPath)]);
    return _m(res);
  }

  static Future<List<dynamic>> myApplications() => ApiClient.get('/api/teachers/applications/mine').then(_l);
  static Future<List<dynamic>> applicationsForTeacher(int teacherId) =>
      ApiClient.get('/api/teachers/$teacherId/applications').then(_l);
  static Future<void> cancelApplication(int applicationId) =>
      ApiClient.delete('/api/teachers/applications/$applicationId');
  static Future<List<dynamic>> pendingApplications() => ApiClient.get('/api/teachers/applications/pending').then(_l);
  static Future<void> decideApplication(int applicationId, bool approve, {String? note}) =>
      ApiClient.post('/api/teachers/applications/$applicationId/decide', {'approve': approve, 'note': note});

  static Future<Map<String, dynamic>> createSlot(Map<String, dynamic> payload) =>
      ApiClient.post('/api/teachers/slots', payload).then(_m);
  static Future<Map<String, dynamic>> updateSlot(int slotId, Map<String, dynamic> payload) =>
      ApiClient.put('/api/teachers/slots/$slotId', payload).then(_m);
  // One Slot per matching weekday between startDate/repeatUntil, each at that weekday's own window.
  static Future<List<dynamic>> createRecurringSlots(Map<String, dynamic> payload) =>
      ApiClient.post('/api/teachers/slots/recurring', payload).then(_l);
  static Future<List<dynamic>> mySlots() => ApiClient.get('/api/teachers/slots/mine').then(_l);
  static Future<List<dynamic>> slotsForTeacherAndCourse(int teacherId, int courseId) =>
      ApiClient.get('/api/teachers/$teacherId/courses/$courseId/slots').then(_l);
  static Future<List<dynamic>> busyTimes(int teacherId, String dateStr) =>
      ApiClient.get('/api/teachers/$teacherId/busy', query: {'date': dateStr}).then(_l);
  static Future<void> cancelSlot(int slotId) => ApiClient.delete('/api/teachers/slots/$slotId');
  static Future<void> cancelSlotSeries(String recurrenceGroupId) =>
      ApiClient.delete('/api/teachers/slots/series/${Uri.encodeComponent(recurrenceGroupId)}');
}

class EnrollmentApi {
  static Future<Map<String, dynamic>> book(int slotId) => ApiClient.post('/api/enrollment-requests/book/$slotId').then(_m);
  static Future<List<dynamic>> bookRecurring(List<int> slotIds) =>
      ApiClient.post('/api/enrollment-requests/book-recurring', slotIds).then(_l);
  static Future<List<dynamic>> mine() => ApiClient.get('/api/enrollment-requests/mine').then(_l);
  static Future<void> cancel(int id) => ApiClient.delete('/api/enrollment-requests/$id');
  static Future<List<dynamic>> pendingForTeacher() => ApiClient.get('/api/enrollment-requests/pending-for-teacher').then(_l);
  static Future<List<dynamic>> pendingForAdmin() => ApiClient.get('/api/enrollment-requests/pending-for-admin').then(_l);
  static Future<void> teacherDecide(int id, bool approve, {String? note}) =>
      ApiClient.post('/api/enrollment-requests/$id/teacher-decide', {'approve': approve, 'note': note});
  static Future<void> adminDecide(int id, bool approve, {String? note}) =>
      ApiClient.post('/api/enrollment-requests/$id/admin-decide', {'approve': approve, 'note': note});
}

class SessionApi {
  static Future<List<dynamic>> mine() => ApiClient.get('/api/sessions/mine').then(_l);
  static Future<List<dynamic>> forCourse(int courseId) => ApiClient.get('/api/sessions/course/$courseId').then(_l);
  static Future<Map<String, dynamic>> get(int id) => ApiClient.get('/api/sessions/$id').then(_m);
  static Future<Map<String, dynamic>> setMeetingLink(int id, String link) =>
      ApiClient.put('/api/sessions/$id/meeting', {'meetingLink': link}).then(_m);
  static Future<Map<String, dynamic>> clearMeetingLink(int id) => ApiClient.delete('/api/sessions/$id/meeting').then(_m);
  // Coordinator (assigned to the course) or admin only.
  static Future<Map<String, dynamic>> markAttendance(int id, Map<String, dynamic> payload) =>
      ApiClient.put('/api/sessions/$id/attendance', payload).then(_m);
}

class CourseAccessApi {
  static Future<Map<String, dynamic>> get(int courseId) => ApiClient.get('/api/course-access/$courseId').then(_m);
}

class PostApi {
  static Future<List<dynamic>> forCourse(int courseId) => ApiClient.get('/api/posts/course/$courseId').then(_l);
  static Future<Map<String, dynamic>> create(int courseId, String content) =>
      ApiClient.post('/api/posts/course/$courseId', {'content': content}).then(_m);
  static Future<Map<String, dynamic>> toggleLike(int id) => ApiClient.post('/api/posts/$id/like').then(_m);
  static Future<void> delete(int id) => ApiClient.delete('/api/posts/$id');
}

class AssignmentApi {
  static Future<Map<String, dynamic>> create(Map<String, dynamic> payload, String attachmentPath) async {
    final res = await ApiClient.multipart(
      'POST',
      '/api/assignments',
      jsonParts: {'data': payload},
      files: [ApiFile('attachment', attachmentPath)],
    );
    return _m(res);
  }

  static Future<List<dynamic>> forCourse(int courseId) => ApiClient.get('/api/assignments/course/$courseId').then(_l);
  static Future<Map<String, dynamic>> get(int id) => ApiClient.get('/api/assignments/$id').then(_m);

  static Future<Map<String, dynamic>> submit(int id, {String? filePath, String? textAnswer}) async {
    final res = await ApiClient.multipart(
      'POST',
      '/api/assignments/$id/submit',
      fields: {if (textAnswer != null && textAnswer.isNotEmpty) 'textAnswer': textAnswer},
      files: filePath == null ? [] : [ApiFile('file', filePath)],
    );
    return _m(res);
  }

  static Future<Map<String, dynamic>?> mySubmission(int id) async {
    final res = await ApiClient.get('/api/assignments/$id/submissions/mine');
    return res == null ? null : _m(res);
  }

  static Future<List<dynamic>> submissions(int id) => ApiClient.get('/api/assignments/$id/submissions').then(_l);
  static Future<Map<String, dynamic>> grade(int id, int submissionId, String grade, String? feedback) =>
      ApiClient.post('/api/assignments/$id/submissions/$submissionId/grade', {'grade': grade, 'feedback': feedback}).then(_m);
}

// Chat is scoped to the whole course (one thread covering every class in it).
class ChatApi {
  static Future<List<dynamic>> history(int courseId) => ApiClient.get('/api/chat/course/$courseId').then(_l);
  static Future<Map<String, dynamic>> send(int courseId, String content) =>
      ApiClient.post('/api/chat/course/$courseId/send', {'content': content}).then(_m);
}

// Private Admin<->Coordinator messaging, with an optional file attachment per message.
class DirectMessageApi {
  static Future<List<dynamic>> history(int otherUserId) => ApiClient.get('/api/direct-messages/$otherUserId').then(_l);

  static Future<Map<String, dynamic>> send(int otherUserId, String? content, {String? attachmentPath}) async {
    final res = await ApiClient.multipart(
      'POST',
      '/api/direct-messages/$otherUserId/send',
      fields: {if (content != null && content.isNotEmpty) 'content': content},
      files: attachmentPath == null ? [] : [ApiFile('attachment', attachmentPath)],
    );
    return _m(res);
  }
}

// Admin -> Coordinator tasks with a deadline, plus a per-task file-sharing message thread.
class TaskApi {
  static Future<Map<String, dynamic>> create(Map<String, dynamic> payload) => ApiClient.post('/api/tasks', payload).then(_m);
  static Future<List<dynamic>> mine() => ApiClient.get('/api/tasks/mine').then(_l);
  static Future<Map<String, dynamic>> updateStatus(int id, String status) =>
      ApiClient.put('/api/tasks/$id/status', {'status': status}).then(_m);
  static Future<List<dynamic>> messages(int id) => ApiClient.get('/api/tasks/$id/messages').then(_l);

  static Future<Map<String, dynamic>> sendMessage(int id, String? content, {String? attachmentPath}) async {
    final res = await ApiClient.multipart(
      'POST',
      '/api/tasks/$id/messages/send',
      fields: {if (content != null && content.isNotEmpty) 'content': content},
      files: attachmentPath == null ? [] : [ApiFile('attachment', attachmentPath)],
    );
    return _m(res);
  }
}

class NotificationApi {
  static Future<List<dynamic>> list() => ApiClient.get('/api/notifications').then(_l);
  static Future<void> markRead(int id) => ApiClient.post('/api/notifications/$id/read');
}

class AnnouncementApi {
  static Future<Map<String, dynamic>> create(Map<String, dynamic> payload) =>
      ApiClient.post('/api/announcements', payload).then(_m);
  static Future<List<dynamic>> all() => ApiClient.get('/api/announcements').then(_l);
  static Future<Map<String, dynamic>> get(int id) => ApiClient.get('/api/announcements/$id').then(_m);
  static Future<Map<String, dynamic>> update(int id, Map<String, dynamic> payload) =>
      ApiClient.put('/api/announcements/$id', payload).then(_m);
  static Future<void> delete(int id) => ApiClient.delete('/api/announcements/$id');
  static Future<List<dynamic>> global() => ApiClient.get('/api/announcements/global').then(_l);
  static Future<List<dynamic>> forCourse(int courseId) => ApiClient.get('/api/announcements/course/$courseId').then(_l);
}

// Admin-editable public website content: the Home / About / Contact pages and testimonials.
class SiteApi {
  static Future<Map<String, dynamic>> getPage(String key) => ApiClient.get('/api/site/pages/$key').then(_m);

  static Future<Map<String, dynamic>> updatePage(String key, Map<String, dynamic> payload, {String? imagePath}) async {
    final res = await ApiClient.multipart(
      'PUT',
      '/api/site/pages/$key',
      jsonParts: {'data': payload},
      files: imagePath == null ? [] : [ApiFile('image', imagePath)],
    );
    return _m(res);
  }

  static Future<List<dynamic>> allTestimonials() => ApiClient.get('/api/site/testimonials/all').then(_l);

  static Future<Map<String, dynamic>> createTestimonial(Map<String, dynamic> payload, {String? photoPath}) async {
    final res = await ApiClient.multipart(
      'POST',
      '/api/site/testimonials',
      jsonParts: {'data': payload},
      files: photoPath == null ? [] : [ApiFile('photo', photoPath)],
    );
    return _m(res);
  }

  static Future<Map<String, dynamic>> updateTestimonial(int id, Map<String, dynamic> payload, {String? photoPath}) async {
    final res = await ApiClient.multipart(
      'PUT',
      '/api/site/testimonials/$id',
      jsonParts: {'data': payload},
      files: photoPath == null ? [] : [ApiFile('photo', photoPath)],
    );
    return _m(res);
  }

  static Future<void> deleteTestimonial(int id) => ApiClient.delete('/api/site/testimonials/$id');
}
