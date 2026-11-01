import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { SessionApi } from "../api/endpoints";
import { fmtTimeRange } from "../utils/format";

// One card per course (not per class instance, and not every past/future session listed) —
// just the course and its next upcoming class. Clicking opens the course page, where the full
// calendar of classes for that course lives (see CourseClasses / MonthCalendar). Same view for
// every role, including admin — no separate flat per-session list.
function groupByCourse(sessions) {
  const byCourse = new Map();
  sessions.forEach((s) => {
    if (!byCourse.has(s.courseId)) byCourse.set(s.courseId, []);
    byCourse.get(s.courseId).push(s);
  });
  const now = Date.now();
  return Array.from(byCourse.values()).map((items) => {
    const sorted = items.slice().sort((a, b) => new Date(a.scheduledStart) - new Date(b.scheduledStart));
    const next = sorted.find((s) => new Date(s.scheduledEnd).getTime() >= now) || sorted[sorted.length - 1];
    return { courseId: sorted[0].courseId, courseTitle: sorted[0].courseTitle, teacherName: sorted[0].teacherName, next };
  });
}

export default function Sessions() {
  const [sessions, setSessions] = useState([]);

  useEffect(() => {
    SessionApi.mine().then(setSessions);
  }, []);

  const courses = useMemo(
    () => groupByCourse(sessions).sort((a, b) => a.courseTitle.localeCompare(b.courseTitle)),
    [sessions]
  );

  return (
    <div className="page">
      <h1>My classes</h1>
      <p className="page-subtitle">Pick a course to see its full class calendar and join your next class.</p>
      {courses.length === 0 && <p className="empty-state">No scheduled classes yet.</p>}
      <div className="card-list">
        {courses.map((c) => (
          <Link to={`/courses/${c.courseId}`} key={c.courseId} className="card session-card">
            <div className="card-row">
              <div className="card-row-main">
                <div className="session-course">{c.courseTitle}</div>
                <div className="session-teacher">with {c.teacherName}</div>
              </div>
              {c.next && <span className="pill">Next: {fmtTimeRange(c.next.scheduledStart, c.next.scheduledEnd)}</span>}
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
