import { useCallback, useEffect, useMemo, useState } from "react";
import { SessionApi } from "../api/endpoints";
import { fmtTimeRange, statusColor } from "../utils/format";
import { sameDay, toDateInputValue } from "../utils/date";
import MonthCalendar from "./MonthCalendar";
import MeetingPanel from "./MeetingPanel";
import AttendancePanel from "./AttendancePanel";

// The current user's classes for one course: a "join your class" popup for whichever class is
// happening now or next, a month calendar with class days highlighted, and the selected day's
// class(es) with full meeting controls below it (teacher: start class by adding a Zoom / Google
// Meet link; everyone else: Join meet, unlocked 5 minutes before class).
export default function CourseClasses({ courseId }) {
  const [sessions, setSessions] = useState(null);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    try {
      setSessions(await SessionApi.forCourse(courseId));
    } catch (err) {
      setError(err.message);
    }
  }, [courseId]);

  useEffect(() => {
    load();
  }, [load]);

  // Jump straight to the nearest day with a class once sessions load, instead of always opening
  // on "today" (which is usually empty).
  useEffect(() => {
    if (!sessions || sessions.length === 0) return;
    const now = Date.now();
    const upcoming = sessions
      .filter((s) => new Date(s.scheduledEnd).getTime() >= now)
      .sort((a, b) => new Date(a.scheduledStart) - new Date(b.scheduledStart));
    if (upcoming.length) setSelectedDate(new Date(upcoming[0].scheduledStart));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessions === null]);

  const nextClass = useMemo(() => {
    if (!sessions) return null;
    const now = Date.now();
    return sessions
      .filter((s) => new Date(s.scheduledEnd).getTime() >= now && s.status !== "CANCELLED")
      .sort((a, b) => new Date(a.scheduledStart) - new Date(b.scheduledStart))[0] || null;
  }, [sessions]);

  const dayClasses = useMemo(() => {
    if (!sessions) return [];
    return sessions
      .filter((s) => sameDay(new Date(s.scheduledStart), selectedDate))
      .sort((a, b) => new Date(a.scheduledStart) - new Date(b.scheduledStart));
  }, [sessions, selectedDate]);

  if (error) return <div className="banner banner-error">{error}</div>;
  if (!sessions) return <p className="card-sub">Loading classes...</p>;
  if (sessions.length === 0) return <p className="empty-state">No classes scheduled for this course yet.</p>;

  return (
    <div className="course-classes">
      {nextClass && (
        <div className="next-class-banner">
          <div className="next-class-banner-info">
            <span className="next-class-banner-label">
              {Date.now() >= new Date(nextClass.scheduledStart).getTime() ? "Happening now" : "Next class"}
            </span>
            <span className="card-title">{fmtTimeRange(nextClass.scheduledStart, nextClass.scheduledEnd)}</span>
            <span className="card-sub">{nextClass.teacherName}</span>
          </div>
          <MeetingPanel session={nextClass} onChanged={load} onRefresh={load} />
        </div>
      )}

      <MonthCalendar items={sessions} dateField="scheduledStart" selectedDate={selectedDate} onSelectDate={setSelectedDate} />

      <div className="course-classes-day">
        <p className="card-sub course-classes-day-label">
          {selectedDate.toLocaleDateString(undefined, { weekday: "long", month: "short", day: "numeric" })}
        </p>
        {dayClasses.length === 0 && <p className="empty-state">No classes on {toDateInputValue(selectedDate)}.</p>}
        {dayClasses.map((s) => (
          <div className="course-class" key={s.id}>
            <div className="card-row">
              <div className="card-row-main">
                <span className="course-class-time">{fmtTimeRange(s.scheduledStart, s.scheduledEnd)}</span>
                <div className="card-sub">{s.teacherName}</div>
              </div>
              <span className={`pill status-${statusColor(s.status)}`}>{s.status}</span>
            </div>
            <MeetingPanel session={s} onChanged={load} onRefresh={load} />
            <AttendancePanel session={s} onChanged={load} />
          </div>
        ))}
      </div>
    </div>
  );
}
