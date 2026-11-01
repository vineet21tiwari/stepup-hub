import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { CourseApi, EnrollmentApi, SessionApi } from "../../api/endpoints";
import { useAuth } from "../../context/AuthContext";
import { fmtTimeRange, groupEnrollmentRequests, pickRecentOrUpcoming } from "../../utils/format";

export default function StudentHome() {
  const { user } = useAuth();
  const [courses, setCourses] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [sessions, setSessions] = useState([]);

  useEffect(() => {
    CourseApi.list().then(setCourses);
    EnrollmentApi.mine().then(setBookings);
    SessionApi.mine().then(setSessions);
  }, []);

  // A weekly booking spans many dated occurrences under one batchId — count it as the one request
  // it is, not once per occurrence.
  const pendingCount = groupEnrollmentRequests(bookings.filter((b) => b.status.startsWith("PENDING"))).length;
  const { items: shownClasses, mode } = pickRecentOrUpcoming(sessions);

  return (
    <div className="page">
      <h1>Welcome, {user.name.split(" ")[0]}</h1>
      <p className="page-subtitle">Here's what's happening with your studies.</p>

      <div className="stat-grid">
        <div className="stat-card">
          <div className="stat-value">{courses.length}</div>
          <div className="stat-label">Courses available</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{pendingCount}</div>
          <div className="stat-label">Pending booking requests</div>
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
        {shownClasses.length === 0 && <p className="empty-state">No classes scheduled yet — browse courses and book a slot.</p>}
        <div className="card-list">
          {shownClasses.map((s) => (
            <Link to={`/courses/${s.courseId}`} key={s.id} className="card session-card">
              <div className="session-course">{s.courseTitle}</div>
              <div className="session-teacher">with {s.teacherName}</div>
              <div className="session-time">{fmtTimeRange(s.scheduledStart, s.scheduledEnd)}</div>
            </Link>
          ))}
        </div>
      </div>

      <div className="section">
        <Link to="/student/courses" className="btn btn-primary">
          Browse courses & book a class
        </Link>
      </div>
    </div>
  );
}
