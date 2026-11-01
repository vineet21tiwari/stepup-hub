import { useState } from "react";
import { SessionApi } from "../api/endpoints";
import { useAuth } from "../context/AuthContext";
import { isoToLocalInput, localInputToIso } from "../utils/format";

// Coordinator (or admin) records how long a class actually ran and who was present, after the fact.
// Everyone else on the course (teacher/students/other coordinators/admin) sees the same read-only
// summary — attendance isn't viewer-restricted like the meeting link is.
export default function AttendancePanel({ session, onChanged }) {
  const { user } = useAuth();
  const canMark = user.role === "COORDINATOR" || user.role === "ADMIN";
  const marked = session.durationMinutes != null;
  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState(() => buildInitialForm(session));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  function buildInitialForm(s) {
    const presentByStudent = {};
    s.students.forEach((st) => {
      const existing = s.attendance.find((a) => a.studentId === st.id);
      presentByStudent[st.id] = existing ? existing.present : true;
    });
    return {
      actualStart: isoToLocalInput(s.actualStart || s.scheduledStart),
      actualEnd: isoToLocalInput(s.actualEnd || s.scheduledEnd),
      teacherPresent: s.teacherPresent == null ? true : s.teacherPresent,
      presentByStudent,
    };
  }

  function startEdit() {
    setForm(buildInitialForm(session));
    setError("");
    setEditing(true);
  }

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const updated = await SessionApi.markAttendance(session.id, {
        actualStart: localInputToIso(form.actualStart),
        actualEnd: localInputToIso(form.actualEnd),
        teacherPresent: form.teacherPresent,
        studentAttendance: form.presentByStudent,
      });
      setEditing(false);
      onChanged?.(updated);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (editing) {
    return (
      <form className="attendance-form" onSubmit={submit}>
        {error && <div className="banner banner-error">{error}</div>}
        <div className="form-row">
          <div>
            <label>Actual start</label>
            <input
              type="datetime-local"
              required
              value={form.actualStart}
              onChange={(e) => setForm((f) => ({ ...f, actualStart: e.target.value }))}
            />
          </div>
          <div>
            <label>Actual end</label>
            <input
              type="datetime-local"
              required
              value={form.actualEnd}
              onChange={(e) => setForm((f) => ({ ...f, actualEnd: e.target.value }))}
            />
          </div>
        </div>
        <label className="admin-users-checkbox">
          <input
            type="checkbox"
            checked={form.teacherPresent}
            onChange={(e) => setForm((f) => ({ ...f, teacherPresent: e.target.checked }))}
          />
          Teacher ({session.teacherName}) present
        </label>
        <p className="card-sub attendance-students-label">Students</p>
        <div className="attendance-student-list">
          {session.students.map((st) => (
            <label key={st.id} className="admin-users-checkbox">
              <input
                type="checkbox"
                checked={!!form.presentByStudent[st.id]}
                onChange={(e) => setForm((f) => ({ ...f, presentByStudent: { ...f.presentByStudent, [st.id]: e.target.checked } }))}
              />
              {st.name}
            </label>
          ))}
        </div>
        <div className="btn-group">
          <button className="btn btn-primary btn-sm" type="submit" disabled={busy}>
            {busy ? "Saving..." : "Save attendance"}
          </button>
          <button className="btn btn-ghost btn-sm" type="button" disabled={busy} onClick={() => setEditing(false)}>
            Cancel
          </button>
        </div>
      </form>
    );
  }

  const presentCount = session.attendance.filter((a) => a.present).length;

  return (
    <div className="attendance-summary">
      {marked ? (
        <>
          <p className="card-sub">
            Conducted {session.durationMinutes} min · {presentCount}/{session.students.length} student(s) present · Teacher:{" "}
            {session.teacherPresent ? "present" : "absent"}
          </p>
          {session.attendance.some((a) => !a.present) && (
            <p className="card-sub attendance-absent-names">
              Absent: {session.attendance.filter((a) => !a.present).map((a) => a.studentName).join(", ")}
            </p>
          )}
        </>
      ) : (
        <p className="card-sub">Attendance not recorded yet.</p>
      )}
      {canMark && (
        <button type="button" className="btn btn-ghost btn-sm" onClick={startEdit}>
          {marked ? "Edit attendance" : "Mark attendance"}
        </button>
      )}
    </div>
  );
}
