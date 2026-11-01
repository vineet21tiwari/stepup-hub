import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { CourseApi, EnrollmentApi, TeacherApi } from "../../api/endpoints";
import { fmtTime } from "../../utils/format";
import { fileUrl } from "../../utils/files";
import { dayOfWeekIst, toDateInputValue } from "../../utils/date";
import DayCalendar from "../../components/DayCalendar";

const ACTIVE_STATUSES = ["PENDING_TEACHER", "PENDING_ADMIN", "APPROVED"];

export default function BrowseCourses() {
  const [courses, setCourses] = useState([]);
  const [selectedCourse, setSelectedCourse] = useState(null);
  const [teachers, setTeachers] = useState([]);
  const [selectedTeacher, setSelectedTeacher] = useState(null);
  const [slots, setSlots] = useState([]);
  const [typeFilter, setTypeFilter] = useState("ALL");
  const [viewedDate, setViewedDate] = useState(new Date());
  const [blockedRanges, setBlockedRanges] = useState([]);
  const [myBookedDates, setMyBookedDates] = useState(new Set());
  const [selectedByWeekday, setSelectedByWeekday] = useState({});
  const [booking, setBooking] = useState(false);
  const [status, setStatus] = useState(null);

  useEffect(() => {
    CourseApi.list().then(setCourses);
    refreshMyBookedDates();
  }, []);

  function refreshMyBookedDates() {
    EnrollmentApi.mine().then((requests) => {
      const dates = requests
        .filter((r) => ACTIVE_STATUSES.includes(r.status))
        .map((r) => toDateInputValue(new Date(r.slotStart)));
      setMyBookedDates(new Set(dates));
    });
  }

  async function openCourse(course) {
    setSelectedCourse(course);
    setSelectedTeacher(null);
    setSlots([]);
    setStatus(null);
    setSelectedByWeekday({});
    const t = await CourseApi.teachersForCourse(course.id);
    setTeachers(t);
  }

  async function openTeacher(teacher) {
    setSelectedTeacher(teacher);
    setSelectedByWeekday({});
    setStatus(null);
    const s = await TeacherApi.slotsForTeacherAndCourse(teacher.teacherId, selectedCourse.id);
    const active = s.filter((sl) => !sl.cancelled);
    setSlots(active);
    // Jump straight to whichever day actually has open slots, instead of always showing "today"
    // (which is usually empty and made it look like the teacher had no availability at all).
    const now = new Date();
    const upcoming = active.map((sl) => new Date(sl.startTime)).filter((d) => d >= now);
    setViewedDate(upcoming.length ? upcoming.sort((a, b) => a - b)[0] : now);
  }

  useEffect(() => {
    if (!selectedTeacher) return;
    TeacherApi.busyTimes(selectedTeacher.teacherId, toDateInputValue(viewedDate)).then(
      (ranges) => setBlockedRanges(ranges.map((r) => ({ start: r.start, end: r.end }))),
      () => setBlockedRanges([])
    );
  }, [selectedTeacher, viewedDate]);

  const filteredSlots = useMemo(() => {
    if (typeFilter === "ALL") return slots;
    return slots.filter((s) => s.sessionType === typeFilter);
  }, [slots, typeFilter]);

  const requiredPerWeek = filteredSlots[0]?.classesPerWeek || 0;
  const isWeeklyPlan = requiredPerWeek > 0;
  const selectedCount = Object.keys(selectedByWeekday).length;
  const dayDateStr = toDateInputValue(viewedDate);
  const dayAlreadyBooked = myBookedDates.has(dayDateStr);

  function toggleSelect(slot) {
    const weekday = dayOfWeekIst(new Date(slot.startTime));
    setSelectedByWeekday((prev) => {
      const next = { ...prev };
      if (next[weekday]?.id === slot.id) {
        delete next[weekday];
      } else {
        next[weekday] = slot;
      }
      return next;
    });
  }

  async function book(slot) {
    setBooking(true);
    setStatus(null);
    try {
      await EnrollmentApi.book(slot.id);
      setStatus({ type: "info", text: "Booking request sent! The teacher and admin will review it." });
      refreshMyBookedDates();
      const s = await TeacherApi.slotsForTeacherAndCourse(selectedTeacher.teacherId, selectedCourse.id);
      setSlots(s.filter((sl) => !sl.cancelled));
    } catch (err) {
      setStatus({ type: "error", text: err.message });
    } finally {
      setBooking(false);
    }
  }

  async function confirmWeeklyBooking() {
    setBooking(true);
    setStatus(null);
    try {
      const slotIds = Object.values(selectedByWeekday).map((s) => s.id);
      await EnrollmentApi.bookRecurring(slotIds);
      setStatus({ type: "info", text: "Weekly booking request sent! The teacher and admin will review it." });
      setSelectedByWeekday({});
      refreshMyBookedDates();
      const s = await TeacherApi.slotsForTeacherAndCourse(selectedTeacher.teacherId, selectedCourse.id);
      setSlots(s.filter((sl) => !sl.cancelled));
    } catch (err) {
      setStatus({ type: "error", text: err.message });
    } finally {
      setBooking(false);
    }
  }

  return (
    <div className="page">
      <h1>Available courses</h1>
      <p className="page-subtitle">Pick a course, choose a teacher, and book an open slot.</p>

      <div className="browse-grid">
        <div className="browse-col">
          <h3>Courses</h3>
          <div className="list-select">
            {courses.map((c) => (
              <button
                key={c.id}
                className={`list-select-item ${selectedCourse?.id === c.id ? "active" : ""}`}
                onClick={() => openCourse(c)}
              >
                <div className="list-select-title">{c.title}</div>
                {c.subject && <div className="list-select-sub">{c.subject}</div>}
                {c.description && <div className="list-select-desc">{c.description}</div>}
              </button>
            ))}
            {courses.length === 0 && <p className="empty-state">No courses available yet.</p>}
          </div>
          {selectedCourse && (
            <Link to={`/courses/${selectedCourse.id}`} className="course-announcements-link">
              View announcements for {selectedCourse.title}
            </Link>
          )}
        </div>

        <div className="browse-col">
          <h3>Teachers{selectedCourse ? ` — ${selectedCourse.title}` : ""}</h3>
          {!selectedCourse && <p className="empty-state">Select a course to see teachers.</p>}
          <div className="list-select">
            {teachers.map((t) => (
              <div
                key={t.teacherId}
                className={`list-select-item teacher-card ${selectedTeacher?.teacherId === t.teacherId ? "active" : ""}`}
              >
                <button className="list-select-trigger" onClick={() => openTeacher(t)}>
                  <div className="list-select-title">{t.teacherName}</div>
                  {t.teacherExtraInfo && <div className="list-select-desc">{t.teacherExtraInfo}</div>}
                </button>
                <div className="teacher-media">
                  {t.introVideoUrl ? (
                    <video src={fileUrl(t.introVideoUrl)} controls className="teacher-intro-video" />
                  ) : (
                    <span className="teacher-media-empty">No intro video yet</span>
                  )}
                </div>
              </div>
            ))}
            {selectedCourse && teachers.length === 0 && (
              <p className="empty-state">No approved teachers for this course yet.</p>
            )}
          </div>
        </div>
      </div>

      {selectedTeacher && (
        <div className="section">
          <div className="section-header">
            <h2>Available slots — {selectedTeacher.teacherName}</h2>
          </div>

          <div className="btn-group slot-mode-toggle">
            <button type="button" className={`btn btn-sm ${typeFilter === "ALL" ? "btn-primary" : "btn-ghost"}`} onClick={() => setTypeFilter("ALL")}>
              All
            </button>
            <button
              type="button"
              className={`btn btn-sm ${typeFilter === "ONE_ON_ONE" ? "btn-primary" : "btn-ghost"}`}
              onClick={() => setTypeFilter("ONE_ON_ONE")}
            >
              1-on-1
            </button>
            <button type="button" className={`btn btn-sm ${typeFilter === "GROUP" ? "btn-primary" : "btn-ghost"}`} onClick={() => setTypeFilter("GROUP")}>
              Group
            </button>
          </div>

          {status && <div className={`banner banner-${status.type === "error" ? "error" : "info"}`}>{status.text}</div>}

          {isWeeklyPlan && (
            <div className="banner banner-warn">
              This course needs {requiredPerWeek} class{requiredPerWeek === 1 ? "" : "es"} per week. Selected {selectedCount}/{requiredPerWeek} day
              {requiredPerWeek === 1 ? "" : "s"}.
              {selectedCount === requiredPerWeek && (
                <button className="btn btn-primary btn-sm" style={{ marginLeft: 12 }} disabled={booking} onClick={confirmWeeklyBooking}>
                  {booking ? "Booking..." : "Confirm booking"}
                </button>
              )}
            </div>
          )}

          {filteredSlots.length === 0 ? (
            <p className="empty-state">No slots posted for this course yet.</p>
          ) : (
            <DayCalendar
              date={viewedDate}
              onDateChange={setViewedDate}
              items={filteredSlots}
              dateField="startTime"
              endField="endTime"
              blockedRanges={blockedRanges}
              emptyText="No slots this day"
              dayDisabled={!isWeeklyPlan && dayAlreadyBooked}
              dayDisabledReason={!isWeeklyPlan && dayAlreadyBooked ? "You already have a class booked this day." : null}
              renderItem={(s) => {
                const weekday = dayOfWeekIst(new Date(s.startTime));
                const isSelected = selectedByWeekday[weekday]?.id === s.id;
                return (
                  <button
                    key={s.id}
                    className={`week-slot-chip ${s.full ? "full" : ""} ${isSelected ? "selected" : ""}`}
                    disabled={s.full || booking}
                    onClick={() => (isWeeklyPlan ? toggleSelect(s) : book(s))}
                  >
                    <span className="week-slot-time">
                      {fmtTime(s.startTime)}–{fmtTime(s.endTime)}
                    </span>
                    <span className="week-slot-cap">
                      {s.full
                        ? "Full"
                        : isWeeklyPlan
                        ? isSelected
                          ? "Selected"
                          : "Select day"
                        : booking
                        ? "Booking..."
                        : `${s.bookedCount}/${s.capacity} · Book`}
                    </span>
                  </button>
                );
              }}
            />
          )}
        </div>
      )}
    </div>
  );
}
