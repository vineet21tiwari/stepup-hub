// Pure helpers that turn a course's ClassSessionDto list into an attendance register. Shared by
// the Attendance tab (AttendanceReport) and the Excel / PDF exporters so all three always agree.
// Everything is computed client-side from SessionApi.forCourse — no extra backend endpoint.
const IST = "Asia/Kolkata";

/** "2026-11" style key for the IST calendar month an ISO instant falls in. */
export function monthKey(iso) {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: IST, year: "numeric", month: "2-digit" }).formatToParts(new Date(iso));
  const y = parts.find((p) => p.type === "year").value;
  const m = parts.find((p) => p.type === "month").value;
  return `${y}-${m}`;
}

export function monthLabel(key) {
  const [y, m] = key.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, 15)).toLocaleDateString(undefined, { month: "long", year: "numeric", timeZone: "UTC" });
}

export function fmtShortDate(iso) {
  return new Date(iso).toLocaleDateString(undefined, { timeZone: IST, weekday: "short", day: "numeric", month: "short", year: "numeric" });
}

export function fmtClock(iso) {
  return new Date(iso).toLocaleTimeString(undefined, { timeZone: IST, hour: "2-digit", minute: "2-digit" });
}

export function fmtDuration(minutes) {
  if (minutes == null) return "-";
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (!h) return `${m} min`;
  return m ? `${h}h ${m}m` : `${h}h`;
}

/** Classes that should have attendance: already started and not cancelled. */
export function heldClasses(sessions, now = Date.now()) {
  return sessions
    .filter((s) => s.status !== "CANCELLED" && new Date(s.scheduledStart).getTime() <= now)
    .sort((a, b) => new Date(b.scheduledStart) - new Date(a.scheduledStart));
}

/** Months (newest first) that have at least one held class. */
export function availableMonths(sessions) {
  return Array.from(new Set(heldClasses(sessions).map((s) => monthKey(s.scheduledStart)))).sort().reverse();
}

/**
 * Builds the register for the given sessions.
 * @param sessions   ClassSessionDto[] for one course
 * @param month      "all" or a monthKey
 * @param onlyStudentId when set (a student viewing), the student summary is limited to that student
 */
export function buildReport(sessions, { month = "all", onlyStudentId = null } = {}) {
  const held = heldClasses(sessions).filter((s) => month === "all" || monthKey(s.scheduledStart) === month);

  const classes = held.map((s) => {
    const marked = s.durationMinutes != null;
    const presentIds = new Set(s.attendance.filter((a) => a.present).map((a) => a.studentId));
    const present = s.students.filter((st) => presentIds.has(st.id));
    const absent = s.students.filter((st) => !presentIds.has(st.id));
    return {
      id: s.id,
      scheduledStart: s.scheduledStart,
      scheduledEnd: s.scheduledEnd,
      actualStart: s.actualStart,
      actualEnd: s.actualEnd,
      teacherName: s.teacherName,
      marked,
      durationMinutes: s.durationMinutes,
      teacherPresent: s.teacherPresent,
      totalStudents: s.students.length,
      presentCount: marked ? present.length : null,
      presentNames: marked ? present.map((st) => st.name) : [],
      absentNames: marked ? absent.map((st) => st.name) : [],
      selfPresent: marked && onlyStudentId != null ? presentIds.has(onlyStudentId) : null,
    };
  });

  const markedClasses = held.filter((s) => s.durationMinutes != null);

  // Per-student tally over marked classes the student was booked into.
  const byStudent = new Map();
  markedClasses.forEach((s) => {
    const presentIds = new Set(s.attendance.filter((a) => a.present).map((a) => a.studentId));
    s.students.forEach((st) => {
      if (onlyStudentId != null && st.id !== onlyStudentId) return;
      if (!byStudent.has(st.id)) byStudent.set(st.id, { id: st.id, name: st.name, total: 0, attended: 0 });
      const row = byStudent.get(st.id);
      row.total += 1;
      if (presentIds.has(st.id)) row.attended += 1;
    });
  });
  const students = Array.from(byStudent.values())
    .map((r) => ({ ...r, missed: r.total - r.attended, percent: r.total ? Math.round((r.attended / r.total) * 100) : 0 }))
    .sort((a, b) => a.percent - b.percent || a.name.localeCompare(b.name));

  const seatTotal = markedClasses.reduce((n, s) => n + s.students.length, 0);
  const seatPresent = classes.reduce((n, c) => n + (c.presentCount || 0), 0);
  const teacherPresentCount = markedClasses.filter((s) => s.teacherPresent).length;
  const minutes = markedClasses.reduce((n, s) => n + (s.durationMinutes || 0), 0);

  const selfRow = onlyStudentId != null ? students[0] : null;
  return {
    classes,
    students,
    summary: {
      held: held.length,
      marked: markedClasses.length,
      pending: held.length - markedClasses.length,
      // For a student viewer the headline % is their own, not the class average.
      attendancePercent: selfRow
        ? selfRow.percent
        : seatTotal ? Math.round((seatPresent / seatTotal) * 100) : null,
      teacherPercent: markedClasses.length ? Math.round((teacherPresentCount / markedClasses.length) * 100) : null,
      minutes,
    },
  };
}

/** ok / warn / bad tone for a percentage, used for bars and pills. */
export function percentTone(p) {
  if (p == null) return "";
  if (p >= 75) return "ok";
  if (p >= 50) return "warn";
  return "bad";
}
