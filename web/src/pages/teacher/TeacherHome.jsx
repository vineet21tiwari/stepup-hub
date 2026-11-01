import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { EnrollmentApi, SessionApi, TeacherApi } from "../../api/endpoints";
import { useAuth } from "../../context/AuthContext";
import { fmtTimeRange, groupEnrollmentRequests, pickRecentOrUpcoming } from "../../utils/format";

export default function TeacherHome() {
  const { user } = useAuth();
  const [applications, setApplications] = useState([]);
  const [pendingBookings, setPendingBookings] = useState([]);
  const [sessions, setSessions] = useState([]);

  useEffect(() => {
    TeacherApi.myApplications().then(setApplications);
    EnrollmentApi.pendingForTeacher().then(setPendingBookings);
    SessionApi.mine().then(setSessions);
  }, []);

  const { items: shownClasses, mode } = pickRecentOrUpcoming(sessions);
  // A weekly booking spans many dated occurrences under one batchId — count it as the one request
  // it is to the student, not once per occurrence.
  const pendingRequestCount = groupEnrollmentRequests(pendingBookings).length;

  return (
    <div className="page">
      <h1>Welcome, {user.name.split(" ")[0]}</h1>
      {!user.approved && (
        <div className="banner banner-warn">
          Your teacher profile is pending Admin approval. You can still apply to courses, but students won't see you until
          you're approved.
        </div>
      )}

      <div className="stat-grid">
        <div className="stat-card">
          <div className="stat-value">{applications.filter((a) => a.status === "APPROVED").length}</div>
          <div className="stat-label">Courses you teach</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{pendingRequestCount}</div>
          <div className="stat-label">Booking requests to review</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{sessions.filter((s) => s.status === "SCHEDULED").length}</div>
          <div className="stat-label">Scheduled classes</div>
        </div>
      </div>

      <div className="section">
        <div className="section-header">
          <h2>{mode === "upcoming" ? "Upcoming classes" : "Recent classes"}</h2>
          <Link to="/sessions">View all my classes</Link>
        </div>
        {shownClasses.length === 0 && <p className="empty-state">Nothing scheduled yet.</p>}
        <div className="card-list">
          {shownClasses.map((s) => (
            <Link to={`/courses/${s.courseId}`} key={s.id} className="card session-card">
              <div className="session-course">{s.courseTitle}</div>
              <div className="session-teacher">{s.students.length} student(s)</div>
              <div className="session-time">{fmtTimeRange(s.scheduledStart, s.scheduledEnd)}</div>
            </Link>
          ))}
        </div>
      </div>

      {pendingRequestCount > 0 && (
        <div className="section">
          <div className="section-header">
            <h2>Booking requests waiting on you</h2>
            <Link to="/teacher/approvals">Review all</Link>
          </div>
        </div>
      )}
    </div>
  );
}
