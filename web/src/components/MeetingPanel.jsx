import { useEffect, useState } from "react";
import { SessionApi } from "../api/endpoints";
import { useAuth } from "../context/AuthContext";
import { fmtDateTime } from "../utils/format";

const PROVIDER_LABEL = { ZOOM: "Zoom", GOOGLE_MEET: "Google Meet" };

// Links are validated server-side, but only ever render an https URL as an href.
function safeHref(url) {
  return url && /^https:\/\//i.test(url) ? url : null;
}

// The class meeting for one session. The teacher starts the class by adding a Zoom / Google Meet link;
// everyone else gets a "Join meet" button that unlocks 5 minutes before the scheduled start.
// `onChanged(updatedSession)` is called after the teacher saves/removes a link; `onRefresh()` after
// the join window opens, to pick up the link the server withholds until then.
export default function MeetingPanel({ session, onChanged, onRefresh }) {
  const { user } = useAuth();
  const [now, setNow] = useState(() => Date.now());
  const [editing, setEditing] = useState(false);
  const [link, setLink] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 15000);
    return () => clearInterval(t);
  }, []);

  const isTeacher = user.role === "TEACHER" && user.id === session.teacherId;
  const opensAt = new Date(session.joinOpensAt).getTime();
  const endsAt = new Date(session.scheduledEnd).getTime();
  const inactive = session.status === "CANCELLED" || session.status === "COMPLETED";
  const ended = inactive || now >= endsAt;
  const windowOpen = !inactive && now >= opensAt && now < endsAt;

  // The server hides the link from students/coordinators until the window opens; once it does
  // (by our clock), re-fetch so the button can turn on without a manual page reload.
  const needsRefresh = !isTeacher && windowOpen && session.hasMeetingLink && !session.meetingLink;
  useEffect(() => {
    if (needsRefresh && onRefresh) onRefresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [needsRefresh]);

  async function save(e) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const updated = await SessionApi.setMeetingLink(session.id, link.trim());
      setEditing(false);
      setLink("");
      onChanged?.(updated);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function remove() {
    if (!confirm("Remove the meeting link from this class?")) return;
    setBusy(true);
    setError("");
    try {
      onChanged?.(await SessionApi.clearMeetingLink(session.id));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  const href = safeHref(session.meetingLink);
  const provider = PROVIDER_LABEL[session.meetingProvider];

  if (isTeacher) {
    return (
      <div className="meeting-panel">
        {error && <div className="banner banner-error">{error}</div>}
        {editing ? (
          <form className="meeting-form" onSubmit={save}>
            <label>Zoom or Google Meet link</label>
            <input
              type="url"
              required
              autoFocus
              placeholder="https://meet.google.com/abc-defg-hij"
              value={link}
              onChange={(e) => setLink(e.target.value)}
            />
            <p className="form-hint">Students and coordinators can join from 5 minutes before the class starts.</p>
            <div className="btn-group">
              <button className="btn btn-primary btn-sm" type="submit" disabled={busy || !link.trim()}>
                {busy ? "Saving..." : "Save link"}
              </button>
              <button className="btn btn-ghost btn-sm" type="button" disabled={busy} onClick={() => setEditing(false)}>
                Cancel
              </button>
            </div>
          </form>
        ) : href ? (
          <>
            <div className="btn-group meeting-actions">
              {!ended && (
                <a href={href} target="_blank" rel="noreferrer" className="btn btn-primary btn-sm">
                  Start class{provider ? ` on ${provider}` : ""}
                </a>
              )}
              {!inactive && (
                <button className="btn btn-ghost btn-sm" disabled={busy} onClick={() => { setLink(session.meetingLink); setEditing(true); }}>
                  Change link
                </button>
              )}
              {!inactive && (
                <button className="btn btn-ghost btn-sm" disabled={busy} onClick={remove}>
                  Remove
                </button>
              )}
            </div>
            {ended && <p className="card-sub">This class has ended.</p>}
          </>
        ) : inactive ? (
          <p className="card-sub">This class is {session.status.toLowerCase()}.</p>
        ) : (
          <>
            <button className="btn btn-primary btn-sm" onClick={() => setEditing(true)}>
              Start class
            </button>
            <p className="card-sub">Add your Zoom or Google Meet link to start this class.</p>
          </>
        )}
      </div>
    );
  }

  return (
    <div className="meeting-panel">
      {ended ? (
        <p className="card-sub">{session.status === "CANCELLED" ? "This class was cancelled." : "This class has ended."}</p>
      ) : !session.hasMeetingLink ? (
        <p className="card-sub">The teacher hasn't added a meeting link yet.</p>
      ) : windowOpen && href ? (
        <a href={href} target="_blank" rel="noreferrer" className="btn btn-primary btn-sm">
          Join meet{provider ? ` (${provider})` : ""}
        </a>
      ) : (
        <>
          <button className="btn btn-primary btn-sm" disabled>
            Join meet
          </button>
          <p className="card-sub">Opens 5 minutes before class, at {fmtDateTime(session.joinOpensAt)}.</p>
        </>
      )}
    </div>
  );
}
