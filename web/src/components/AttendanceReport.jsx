import { useEffect, useMemo, useState } from "react";
import { SessionApi } from "../api/endpoints";
import { useAuth } from "../context/AuthContext";
import {
  availableMonths,
  buildReport,
  fmtClock,
  fmtDuration,
  fmtShortDate,
  monthLabel,
  percentTone,
} from "../utils/attendance";

// Attendance tab on the course page: headline stats, a class-wise register and a per-student
// summary, filterable by month and exportable to Excel / PDF. Built from the same
// SessionApi.forCourse data as the class calendar. A student only sees their own row in the
// student summary (and a "You" column in the register) rather than classmates' percentages.
export default function AttendanceReport({ courseId, courseTitle }) {
  const { user } = useAuth();
  const isStudentView = user.role === "STUDENT";
  const [sessions, setSessions] = useState(null);
  const [error, setError] = useState("");
  const [month, setMonth] = useState("all");
  const [view, setView] = useState("classes");
  const [exporting, setExporting] = useState("");

  useEffect(() => {
    SessionApi.forCourse(courseId).then(setSessions).catch((err) => setError(err.message));
  }, [courseId]);

  const months = useMemo(() => (sessions ? availableMonths(sessions) : []), [sessions]);
  const report = useMemo(
    () => (sessions ? buildReport(sessions, { month, onlyStudentId: isStudentView ? user.id : null }) : null),
    [sessions, month, isStudentView, user.id]
  );
  const periodLabel = month === "all" ? "All time" : monthLabel(month);

  async function doExport(kind) {
    setExporting(kind);
    setError("");
    try {
      const mod = await import("../utils/attendanceExport");
      const args = { courseTitle, periodLabel, report, isStudentView };
      if (kind === "excel") await mod.exportAttendanceExcel(args);
      else await mod.exportAttendancePdf(args);
    } catch (err) {
      setError(`Export failed: ${err.message}`);
    } finally {
      setExporting("");
    }
  }

  if (error && !sessions) return <div className="banner banner-error">{error}</div>;
  if (!report) return <p className="card-sub">Loading attendance...</p>;

  const { summary } = report;
  const empty = summary.held === 0;

  return (
    <div className="att-report">
      <div className="att-toolbar">
        <div className="att-toolbar-filter">
          <label htmlFor="att-month">Period</label>
          <select id="att-month" value={month} onChange={(e) => setMonth(e.target.value)}>
            <option value="all">All time</option>
            {months.map((m) => (
              <option key={m} value={m}>{monthLabel(m)}</option>
            ))}
          </select>
        </div>
        <div className="att-toolbar-export">
          <button type="button" className="btn btn-ghost btn-sm att-export-btn" disabled={empty || !!exporting} onClick={() => doExport("excel")}>
            <span className="att-export-icon att-export-xls" aria-hidden="true">XLS</span>
            {exporting === "excel" ? "Preparing..." : "Excel"}
          </button>
          <button type="button" className="btn btn-ghost btn-sm att-export-btn" disabled={empty || !!exporting} onClick={() => doExport("pdf")}>
            <span className="att-export-icon att-export-pdf" aria-hidden="true">PDF</span>
            {exporting === "pdf" ? "Preparing..." : "PDF"}
          </button>
        </div>
      </div>
      {error && <div className="banner banner-error">{error}</div>}

      {empty ? (
        <p className="empty-state">No classes have taken place {month === "all" ? "yet" : `in ${periodLabel}`}.</p>
      ) : (
        <>
          <div className="att-stats">
            <StatTile
              value={summary.attendancePercent == null ? "-" : `${summary.attendancePercent}%`}
              label={isStudentView ? "Your attendance" : "Avg. attendance"}
              tone={percentTone(summary.attendancePercent)}
              percent={summary.attendancePercent}
            />
            <StatTile value={`${summary.marked}/${summary.held}`} label="Classes marked" />
            <StatTile
              value={summary.teacherPercent == null ? "-" : `${summary.teacherPercent}%`}
              label="Teacher present"
              tone={percentTone(summary.teacherPercent)}
              percent={summary.teacherPercent}
            />
            <StatTile value={fmtDuration(summary.minutes)} label="Time taught" />
          </div>

          {summary.pending > 0 && (
            <div className="banner att-pending-banner">
              {summary.pending} past class{summary.pending === 1 ? "" : "es"} still {summary.pending === 1 ? "has" : "have"} no attendance recorded.
            </div>
          )}

          <div className="segmented att-view-switch">
            <button type="button" className={`segmented-btn ${view === "classes" ? "active" : ""}`} onClick={() => setView("classes")}>
              Class-wise ({report.classes.length})
            </button>
            <button type="button" className={`segmented-btn ${view === "students" ? "active" : ""}`} onClick={() => setView("students")}>
              {isStudentView ? "My summary" : `Student-wise (${report.students.length})`}
            </button>
          </div>

          {view === "classes" ? (
            <ClassRegister classes={report.classes} isStudentView={isStudentView} />
          ) : (
            <StudentSummary students={report.students} />
          )}
        </>
      )}
    </div>
  );
}

function StatTile({ value, label, tone = "", percent = null }) {
  return (
    <div className={`att-stat ${tone ? `att-tone-${tone}` : ""}`}>
      <div className="att-stat-value">{value}</div>
      <div className="att-stat-label">{label}</div>
      {percent != null && (
        <div className="att-bar" aria-hidden="true">
          <span style={{ width: `${percent}%` }} />
        </div>
      )}
    </div>
  );
}

function ClassRegister({ classes, isStudentView }) {
  return (
    <div className="att-table-wrap">
      <table className="att-table">
        <thead>
          <tr>
            <th>Date</th>
            <th>Teacher</th>
            <th>Duration</th>
            <th>{isStudentView ? "You" : "Students"}</th>
            {!isStudentView && <th>Absent</th>}
          </tr>
        </thead>
        <tbody>
          {classes.map((c) => (
            <tr key={c.id} className={c.marked ? "" : "att-row-pending"}>
              <td data-label="Date">
                <div className="att-cell-strong">{fmtShortDate(c.scheduledStart)}</div>
                <div className="att-cell-sub">{fmtClock(c.scheduledStart)} - {fmtClock(c.scheduledEnd)}</div>
              </td>
              <td data-label="Teacher">
                <div>{c.teacherName}</div>
                {c.marked && (
                  <span className={`pill small status-${c.teacherPresent ? "ok" : "bad"}`}>
                    {c.teacherPresent ? "Present" : "Absent"}
                  </span>
                )}
              </td>
              <td data-label="Duration">{c.marked ? fmtDuration(c.durationMinutes) : "-"}</td>
              <td data-label={isStudentView ? "You" : "Students"}>
                {!c.marked ? (
                  <span className="pill status-warn">Not marked</span>
                ) : isStudentView ? (
                  <span className={`pill status-${c.selfPresent ? "ok" : "bad"}`}>{c.selfPresent ? "Present" : "Absent"}</span>
                ) : (
                  <div className="att-count">
                    <span className="att-cell-strong">{c.presentCount}/{c.totalStudents}</span>
                    <div className={`att-bar att-bar-inline att-tone-${percentTone(c.totalStudents ? (c.presentCount / c.totalStudents) * 100 : 0)}`}>
                      <span style={{ width: `${c.totalStudents ? (c.presentCount / c.totalStudents) * 100 : 0}%` }} />
                    </div>
                  </div>
                )}
              </td>
              {!isStudentView && (
                <td data-label="Absent" className="att-absent">
                  {c.marked ? (c.absentNames.length ? c.absentNames.join(", ") : <span className="att-none">None</span>) : "-"}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function StudentSummary({ students }) {
  if (students.length === 0) return <p className="empty-state">No marked classes yet.</p>;
  return (
    <ul className="att-students">
      {students.map((s) => {
        const tone = percentTone(s.percent);
        return (
          <li key={s.id} className="att-student">
            <div className="att-student-avatar" aria-hidden="true">{s.name.slice(0, 1).toUpperCase()}</div>
            <div className="att-student-main">
              <div className="att-student-top">
                <span className="att-cell-strong">{s.name}</span>
                <span className={`pill status-${tone}`}>{s.percent}%</span>
              </div>
              <div className={`att-bar att-tone-${tone}`} aria-hidden="true">
                <span style={{ width: `${s.percent}%` }} />
              </div>
              <div className="att-cell-sub">
                Attended {s.attended} of {s.total} · Missed {s.missed}
              </div>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
