import { useCallback, useEffect, useState } from "react";
import { SessionApi } from "../api/endpoints";
import { useAuth } from "../context/AuthContext";
import { fmtDateTime, isoToLocalInput, localInputToIso } from "../utils/format";

// Tomorrow's date in IST as a datetime-local minimum (changes are never allowed onto "today").
function tomorrowMin() {
  const d = new Date(Date.now() + 24 * 3600 * 1000).toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" });
  return `${d}T00:00`;
}

export function ChangeRequestCard({ r, onChanged, showClass = false }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function act(fn) {
    setBusy(true);
    setError("");
    try {
      await fn();
      onChanged?.();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  const statusCls = r.status === "APPROVED" ? "ok" : r.status === "PENDING" ? "warn" : "bad";
  return (
    <div className="change-request">
      {error && <div className="banner banner-error">{error}</div>}
      <div className="change-request-head">
        <span className="pill small">{r.type === "CANCEL" ? "Cancel class" : "Reschedule"}</span>
        <span className={`pill small status-${statusCls}`}>{r.status}</span>
        {showClass && <strong className="change-request-course">{r.courseTitle}</strong>}
      </div>
      <div className="card-sub">
        Requested by <strong>{r.requestedByName}</strong> ({r.requesterRole.toLowerCase()})
        {showClass && <> · Teacher {r.teacherName} · Students {r.studentNames.join(", ") || "—"}</>}
      </div>
      <div className="change-request-times">
        <span>{fmtDateTime(r.originalStart)}</span>
        {r.type === "RESCHEDULE" && (
          <>
            <span className="change-request-arrow">→</span>
            <span className="change-request-new">{fmtDateTime(r.newStart)}</span>
          </>
        )}
      </div>
      {r.reason && <p className="card-sub">“{r.reason}”</p>}
      {r.status === "PENDING" && (
        <div className="card-sub">
          {r.approvedBy.length > 0 && <>Approved by {r.approvedBy.join(", ")} · </>}
          Waiting for {r.awaiting.join(", ")}
        </div>
      )}
      {r.status === "REJECTED" && r.rejectedByName && <div className="card-sub">Declined by {r.rejectedByName}</div>}
      {(r.canDecide || r.canWithdraw) && (
        <div className="btn-group btn-group-wrap change-request-actions">
          {r.canDecide && (
            <>
              <button className="btn btn-primary btn-sm" disabled={busy} onClick={() => act(() => SessionApi.decideChange(r.id, true))}>
                Approve
              </button>
              <button className="btn btn-ghost btn-sm" disabled={busy} onClick={() => act(() => SessionApi.decideChange(r.id, false))}>
                Decline
              </button>
            </>
          )}
          {r.canWithdraw && (
            <button className="btn btn-ghost btn-sm" disabled={busy} onClick={() => act(() => SessionApi.withdrawChange(r.id))}>
              Withdraw
            </button>
          )}
        </div>
      )}
    </div>
  );
}

// Per-class: shows pending change requests and lets the teacher or a student of the class ask to
// reschedule/cancel it (allowed up to the day before — never on the class day).
export default function ClassChangePanel({ session, onApplied }) {
  const { user } = useAuth();
  const [requests, setRequests] = useState([]);
  const [mode, setMode] = useState(null); // "RESCHEDULE" | "CANCEL" | null
  const [form, setForm] = useState({ start: "", end: "", reason: "" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const isTeacher = user?.id === session.teacherId;
  const isStudent = (session.students || []).some((s) => s.id === user?.id);
  const canRaise = (isTeacher || isStudent) && session.changeAllowed;

  const load = useCallback(() => {
    SessionApi.changeRequestsFor(session.id).then(setRequests).catch(() => setRequests([]));
  }, [session.id]);

  useEffect(() => {
    load();
  }, [load]);

  const pending = requests.filter((r) => r.status === "PENDING");
  const recent = requests.filter((r) => r.status !== "PENDING").slice(0, 1);

  function openMode(m) {
    setError("");
    setMode(m);
    if (m === "RESCHEDULE") {
      setForm({ start: isoToLocalInput(session.scheduledStart), end: isoToLocalInput(session.scheduledEnd), reason: "" });
    } else {
      setForm({ start: "", end: "", reason: "" });
    }
  }

  async function submit(e) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await SessionApi.requestChange(session.id, {
        type: mode,
        newStart: mode === "RESCHEDULE" ? localInputToIso(form.start) : null,
        newEnd: mode === "RESCHEDULE" ? localInputToIso(form.end) : null,
        reason: form.reason.trim() || null,
      });
      setMode(null);
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  const showTodayHint = (isTeacher || isStudent) && session.status === "SCHEDULED" && !session.changeAllowed
    && new Date(session.scheduledStart).getTime() > Date.now();

  if (!canRaise && pending.length === 0 && recent.length === 0 && !showTodayHint) return null;

  return (
    <div className="class-change-panel">
      {pending.map((r) => (
        <ChangeRequestCard key={r.id} r={r} onChanged={() => { load(); onApplied?.(); }} />
      ))}
      {pending.length === 0 && recent.map((r) => <ChangeRequestCard key={r.id} r={r} />)}

      {canRaise && pending.length === 0 && !mode && (
        <div className="btn-group btn-group-wrap">
          <button className="btn btn-ghost btn-sm" onClick={() => openMode("RESCHEDULE")}>
            Request time change
          </button>
          <button className="btn btn-ghost btn-sm btn-danger-ghost" onClick={() => openMode("CANCEL")}>
            Request cancellation
          </button>
        </div>
      )}
      {showTodayHint && <p className="form-hint">Classes can't be changed or cancelled on the day of the class.</p>}

      {mode && (
        <form className="change-form" onSubmit={submit}>
          {error && <div className="banner banner-error">{error}</div>}
          {mode === "RESCHEDULE" && (
            <div className="form-row">
              <div>
                <label>New start</label>
                <input type="datetime-local" required min={tomorrowMin()} value={form.start} onChange={(e) => setForm((f) => ({ ...f, start: e.target.value }))} />
              </div>
              <div>
                <label>New end</label>
                <input type="datetime-local" required min={form.start || tomorrowMin()} value={form.end} onChange={(e) => setForm((f) => ({ ...f, end: e.target.value }))} />
              </div>
            </div>
          )}
          <label>Reason (optional)</label>
          <input value={form.reason} maxLength={500} onChange={(e) => setForm((f) => ({ ...f, reason: e.target.value }))} placeholder="Let everyone know why" />
          <p className="form-hint">
            {isTeacher ? "The student(s) and an admin must approve." : "Your teacher and an admin must approve."}
          </p>
          <div className="btn-group btn-group-wrap">
            <button className="btn btn-primary btn-sm" type="submit" disabled={busy}>
              {busy ? "Sending..." : mode === "CANCEL" ? "Send cancellation request" : "Send change request"}
            </button>
            <button className="btn btn-ghost btn-sm" type="button" onClick={() => setMode(null)}>
              Back
            </button>
          </div>
        </form>
      )}
    </div>
  );
}
