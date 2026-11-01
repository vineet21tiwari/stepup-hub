import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { AnnouncementApi, CourseApi, SessionApi } from "../api/endpoints";
import { subscribeToUserNotifications } from "../api/socket";
import { useAuth } from "../context/AuthContext";
import { fmtTimeRange } from "../utils/format";
import MeetingPanel from "../components/MeetingPanel";
import AttendancePanel from "../components/AttendancePanel";

export default function SessionDetail() {
  const { id } = useParams();
  const { user } = useAuth();
  const [session, setSession] = useState(null);
  const [courseCoordinators, setCourseCoordinators] = useState([]);
  const [error, setError] = useState("");
  const [announcements, setAnnouncements] = useState([]);

  async function load() {
    try {
      setSession(await SessionApi.get(id));
    } catch (err) {
      setError(err.message);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  // Coordinators are assigned at the course level now (see AdminCoordinators) — just display them here.
  useEffect(() => {
    if (!session?.courseId) return;
    CourseApi.coordinatorsForCourse(session.courseId).then(setCourseCoordinators).catch(() => setCourseCoordinators([]));
  }, [session?.courseId]);

  // Show this class's course announcements live in the classroom, refreshing whenever a new
  // notification comes in (e.g. the teacher or admin posts one for this course while the class is in session).
  useEffect(() => {
    if (!session?.courseId) return;
    function loadAnnouncements() {
      AnnouncementApi.forCourse(session.courseId).then(setAnnouncements).catch(() => {});
    }
    loadAnnouncements();
    const unsub = user ? subscribeToUserNotifications(user.id, loadAnnouncements) : () => {};
    return unsub;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session?.courseId, user?.id]);

  if (!session) {
    return error ? (
      <div className="page">
        <div className="banner banner-error">{error}</div>
      </div>
    ) : (
      <div className="page-loading">Loading...</div>
    );
  }

  return (
    <div className="page">
      <h1>{session.courseTitle}</h1>
      <p className="page-subtitle">{fmtTimeRange(session.scheduledStart, session.scheduledEnd)}</p>
      <Link to={`/courses/${session.courseId}`} className="card-sub">
        Open course page: posts, announcements and assignments
      </Link>

      <div className="session-meeting-cta">
        <MeetingPanel session={session} onChanged={setSession} onRefresh={load} />
      </div>

      {announcements.length > 0 && (
        <div className="announcement-strip session-announcements">
          {announcements.slice(0, 3).map((a) => (
            <div className="announcement-banner" key={a.id}>
              <div>
                <span className="announcement-title">{a.title}</span>
                <span className="announcement-message">{a.message}</span>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="session-detail-grid">
        <div className="card">
          <div className="card-title">Class details</div>
          <p className="card-sub">Teacher: {session.teacherName}</p>
          <p className="card-sub">
            Coordinator{courseCoordinators.length === 1 ? "" : "s"}:{" "}
            {courseCoordinators.length ? courseCoordinators.map((c) => c.name).join(", ") : "Not assigned yet"}
          </p>
          <p className="card-sub">Status: {session.status}</p>
          <p className="card-sub">Students ({session.students.length}):</p>
          <ul className="plain-list">
            {session.students.map((s) => (
              <li key={s.id}>{s.name}</li>
            ))}
          </ul>
          <div className="assign-coordinator">
            <p className="card-sub course-side-label">Attendance</p>
            <AttendancePanel session={session} onChanged={setSession} />
          </div>
          {user.role === "ADMIN" && (
            <Link to="/admin/coordinators" className="card-sub">
              Manage coordinator assignments
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}
