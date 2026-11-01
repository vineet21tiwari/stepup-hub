import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { CoordinatorApi, SessionApi } from "../../api/endpoints";
import { useAuth } from "../../context/AuthContext";
import { fmtTimeRange, pickRecentOrUpcoming } from "../../utils/format";

export default function CoordinatorHome() {
  const { user } = useAuth();
  const [sessions, setSessions] = useState([]);
  const [courses, setCourses] = useState([]);

  useEffect(() => {
    SessionApi.mine().then(setSessions);
    CoordinatorApi.coursesFor(user.id).then(setCourses);
  }, [user.id]);

  const { items: shownClasses, mode } = pickRecentOrUpcoming(sessions);

  return (
    <div className="page">
      <h1>Welcome, {user.name.split(" ")[0]}</h1>
      <p className="page-subtitle">Classes you're coordinating.</p>

      <div className="stat-grid">
        <div className="stat-card">
          <div className="stat-value">{courses.length}</div>
          <div className="stat-label">Courses assigned</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{sessions.filter((s) => s.status === "SCHEDULED").length}</div>
          <div className="stat-label">Scheduled classes</div>
        </div>
      </div>

      <div className="section">
        <h2>My courses</h2>
        <div className="card-list">
          {courses.map((c) => (
            <Link to={`/courses/${c.id}`} key={c.id} className="card">
              <div className="card-title">{c.title}</div>
              {c.subject && <div className="card-sub">{c.subject}</div>}
            </Link>
          ))}
          {courses.length === 0 && <p className="empty-state">No courses assigned to you yet.</p>}
        </div>
      </div>

      <div className="section">
        <h2>{mode === "upcoming" ? "Upcoming classes" : "Recent classes"}</h2>
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
          {shownClasses.length === 0 && (
            <p className="empty-state">No classes assigned to you yet — an admin assigns coordinators to courses.</p>
          )}
        </div>
      </div>
    </div>
  );
}
