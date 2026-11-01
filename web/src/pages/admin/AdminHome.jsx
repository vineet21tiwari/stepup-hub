import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { CourseApi, EnrollmentApi, SessionApi, TeacherApi, UserApi } from "../../api/endpoints";
import { useAuth } from "../../context/AuthContext";
import { fmtTimeRange, groupEnrollmentRequests, pickRecentOrUpcoming } from "../../utils/format";

export default function AdminHome() {
  const { user } = useAuth();
  const [courses, setCourses] = useState([]);
  const [teacherApps, setTeacherApps] = useState([]);
  const [bookingApprovals, setBookingApprovals] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [students, setStudents] = useState([]);
  const [teachers, setTeachers] = useState([]);

  useEffect(() => {
    CourseApi.list().then(setCourses);
    TeacherApi.pendingApplications().then(setTeacherApps);
    EnrollmentApi.pendingForAdmin().then(setBookingApprovals);
    SessionApi.mine().then(setSessions);
    UserApi.byRole("STUDENT").then(setStudents);
    UserApi.byRole("TEACHER").then(setTeachers);
  }, []);

  // A weekly booking spans many dated occurrences under one batchId — count it as the one request
  // it is to the student, not once per occurrence.
  const pendingBookingCount = groupEnrollmentRequests(bookingApprovals).length;
  const { items: shownClasses, mode } = pickRecentOrUpcoming(sessions);

  return (
    <div className="page">
      <h1>Welcome, {user.name.split(" ")[0]}</h1>
      <p className="page-subtitle">Platform overview.</p>

      <div className="stat-grid">
        <div className="stat-card">
          <div className="stat-value">{courses.length}</div>
          <div className="stat-label">Active courses</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{students.length}</div>
          <div className="stat-label">Students</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{teachers.length}</div>
          <div className="stat-label">Teachers</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{sessions.filter((s) => s.status === "SCHEDULED").length}</div>
          <div className="stat-label">Scheduled classes</div>
        </div>
      </div>

      <div className="section-grid">
        <div className="section">
          <div className="section-header">
            <h2>Teacher applications awaiting review</h2>
            <Link to="/admin/teacher-applications">Review</Link>
          </div>
          <div className="stat-inline">{teacherApps.length} pending</div>
        </div>
        <div className="section">
          <div className="section-header">
            <h2>Bookings awaiting final approval</h2>
            <Link to="/admin/bookings">Review</Link>
          </div>
          <div className="stat-inline">{pendingBookingCount} pending</div>
        </div>
      </div>

      <div className="section">
        <div className="section-header">
          <h2>{mode === "upcoming" ? "Upcoming classes" : "Recent classes"}</h2>
          <Link to="/sessions">View all classes</Link>
        </div>
        <div className="card-list">
          {shownClasses.map((s) => (
            <Link to={`/courses/${s.courseId}`} key={s.id} className="card session-card">
              <div className="session-course">{s.courseTitle}</div>
              <div className="session-teacher">
                {s.teacherName} · {s.students.length} student(s)
              </div>
              <div className="session-time">{fmtTimeRange(s.scheduledStart, s.scheduledEnd)}</div>
            </Link>
          ))}
          {shownClasses.length === 0 && <p className="empty-state">No classes scheduled yet.</p>}
        </div>
      </div>

      <div className="section">
        <Link to="/admin/courses" className="btn btn-primary">
          Manage courses
        </Link>
      </div>
    </div>
  );
}
