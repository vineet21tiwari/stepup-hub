import { useEffect, useState } from "react";
import { AssignmentApi } from "../api/endpoints";
import { fmtDateTime, statusColor } from "../utils/format";
import ResumePreview from "./ResumePreview";

const STATUS_LABEL = { SUBMITTED: "Submitted", LATE: "Submitted late", GRADED: "Graded" };

function statusPillClass(status) {
  if (status === "GRADED") return "status-ok";
  if (status === "LATE") return "status-warn";
  return statusColor(status) ? `status-${statusColor(status)}` : "";
}

// Student side of an assignment: hand in a file and/or a written answer, resubmit until it is graded,
// then see the grade and feedback.
export function StudentSubmission({ assignment }) {
  const [submission, setSubmission] = useState(undefined); // undefined = loading, null = none yet
  const [open, setOpen] = useState(false);
  const [file, setFile] = useState(null);
  const [fileKey, setFileKey] = useState(0);
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    AssignmentApi.mySubmission(assignment.id)
      .then((s) => {
        if (cancelled) return;
        setSubmission(s);
        setText(s?.textAnswer || "");
      })
      .catch((err) => {
        if (cancelled) return;
        setSubmission(null);
        setError(err.message);
      });
    return () => {
      cancelled = true;
    };
  }, [assignment.id]);

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const saved = await AssignmentApi.submit(assignment.id, file, text.trim());
      setSubmission(saved);
      setFile(null);
      setFileKey((k) => k + 1);
      setOpen(false);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (submission === undefined) return null;

  const graded = submission?.status === "GRADED";
  const pastDue = new Date(assignment.dueDate).getTime() < Date.now();

  return (
    <div className="submission-box">
      {submission && (
        <div className="submission-summary">
          <span className={`pill ${statusPillClass(submission.status)}`}>{STATUS_LABEL[submission.status] || submission.status}</span>
          <span className="card-sub">Submitted {fmtDateTime(submission.submittedAt)}</span>
        </div>
      )}
      {graded && (
        <div className="submission-grade">
          <strong>Grade: {submission.grade}</strong>
          {submission.feedback && <p className="feed-item-body">{submission.feedback}</p>}
        </div>
      )}
      {error && <div className="banner banner-error">{error}</div>}

      {!graded && !open && (
        <button type="button" className="btn btn-primary btn-sm" onClick={() => setOpen(true)}>
          {submission ? "Resubmit" : "Submit work"}
        </button>
      )}
      {!graded && open && (
        <form onSubmit={submit}>
          {pastDue && <div className="banner banner-warn">The due date has passed, so this will be marked as late.</div>}
          <label>File{submission?.fileUrl ? " (leave empty to keep your current file)" : ""}</label>
          <input key={fileKey} type="file" onChange={(e) => setFile(e.target.files?.[0] || null)} />
          <label>Written answer</label>
          <textarea rows="3" maxLength={4000} value={text} onChange={(e) => setText(e.target.value)} />
          <div className="btn-group feed-composer-actions">
            <button type="button" className="btn btn-ghost btn-sm" disabled={busy} onClick={() => setOpen(false)}>
              Cancel
            </button>
            <button className="btn btn-primary btn-sm" type="submit" disabled={busy || (!file && !text.trim() && !submission?.fileUrl)}>
              {busy ? "Submitting..." : "Submit"}
            </button>
          </div>
        </form>
      )}
      {submission?.fileUrl && !open && <ResumePreview url={submission.fileUrl} label="your file" />}
      {submission?.textAnswer && !open && <p className="feed-item-body submission-text">{submission.textAnswer}</p>}
    </div>
  );
}

function GradeForm({ assignmentId, submission, onGraded }) {
  const [grade, setGrade] = useState(submission.grade || "");
  const [feedback, setFeedback] = useState(submission.feedback || "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      onGraded(await AssignmentApi.grade(assignmentId, submission.id, grade.trim(), feedback.trim()));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="grade-form" onSubmit={save}>
      {error && <div className="banner banner-error">{error}</div>}
      <div className="form-row">
        <div>
          <label>Grade</label>
          <input required maxLength={50} placeholder="e.g. 18/20 or A" value={grade} onChange={(e) => setGrade(e.target.value)} />
        </div>
        <div>
          <label>Feedback (optional)</label>
          <input maxLength={2000} value={feedback} onChange={(e) => setFeedback(e.target.value)} />
        </div>
      </div>
      <div className="feed-composer-actions">
        <button className="btn btn-primary btn-sm" type="submit" disabled={busy || !grade.trim()}>
          {busy ? "Saving..." : submission.status === "GRADED" ? "Update grade" : "Save grade"}
        </button>
      </div>
    </form>
  );
}

// Author / admin side: every student's submission for this assignment, with grading.
export function TeacherSubmissions({ assignment }) {
  const [open, setOpen] = useState(false);
  const [list, setList] = useState(null);
  const [error, setError] = useState("");

  async function toggle() {
    const next = !open;
    setOpen(next);
    if (next) {
      setError("");
      try {
        setList(await AssignmentApi.submissions(assignment.id));
      } catch (err) {
        setError(err.message);
      }
    }
  }

  function replace(updated) {
    setList((prev) => prev.map((s) => (s.id === updated.id ? updated : s)));
  }

  return (
    <div className="submission-box">
      <button type="button" className="btn btn-ghost btn-sm" onClick={toggle}>
        {open ? "Hide submissions" : "View submissions"}
      </button>
      {open && error && <div className="banner banner-error">{error}</div>}
      {open && !list && !error && <p className="card-sub">Loading...</p>}
      {open && list && list.length === 0 && <p className="empty-state">No submissions yet.</p>}
      {open &&
        list &&
        list.map((s) => (
          <div className="submission-row" key={s.id}>
            <div className="card-row">
              <div className="card-row-main">
                <strong>{s.studentName}</strong>
                <div className="card-sub">{fmtDateTime(s.submittedAt)}</div>
              </div>
              <span className={`pill ${statusPillClass(s.status)}`}>
                {s.status === "GRADED" ? `Graded: ${s.grade}` : STATUS_LABEL[s.status] || s.status}
              </span>
            </div>
            {s.fileUrl && <ResumePreview url={s.fileUrl} label="file" />}
            {s.textAnswer && <p className="feed-item-body submission-text">{s.textAnswer}</p>}
            <GradeForm assignmentId={assignment.id} submission={s} onGraded={replace} />
          </div>
        ))}
    </div>
  );
}
