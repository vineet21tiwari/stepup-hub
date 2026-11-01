import { useCallback, useEffect, useMemo, useState } from "react";
import { AnnouncementApi, AssignmentApi, PostApi } from "../api/endpoints";
import { useAuth } from "../context/AuthContext";
import { toDateInputValue } from "../utils/date";
import { fmtDate, fmtDateTime, localInputToIso } from "../utils/format";
import ResumePreview from "./ResumePreview";
import { StudentSubmission, TeacherSubmissions } from "./AssignmentSubmissions";

const TYPE_FILTERS = [
  { key: "ALL", label: "All" },
  { key: "POST", label: "Posts" },
  { key: "ANNOUNCEMENT", label: "Announcements" },
  { key: "ASSIGNMENT", label: "Assignments" },
];

const emptyAssignment = { title: "", description: "", due: "", file: null };

// Add-something box at the top of the feed. Every member can write a post; only teachers (approved for the
// course) and admins can add announcements and assignments.
function Composer({ courseId, canManage, onPosted }) {
  const [mode, setMode] = useState("POST");
  const [postText, setPostText] = useState("");
  const [announcement, setAnnouncement] = useState({ title: "", message: "" });
  const [assignment, setAssignment] = useState(emptyAssignment);
  const [fileKey, setFileKey] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function run(fn) {
    setBusy(true);
    setError("");
    try {
      await fn();
      await onPosted();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  function submitPost(e) {
    e.preventDefault();
    run(async () => {
      await PostApi.create(courseId, postText.trim());
      setPostText("");
    });
  }

  function submitAnnouncement(e) {
    e.preventDefault();
    run(async () => {
      await AnnouncementApi.create({
        title: announcement.title.trim(),
        message: announcement.message.trim(),
        scope: "COURSE",
        courseId: Number(courseId),
      });
      setAnnouncement({ title: "", message: "" });
    });
  }

  function submitAssignment(e) {
    e.preventDefault();
    if (!assignment.file || !assignment.file.name.toLowerCase().endsWith(".pdf")) {
      setError("Attach the assignment as a PDF file.");
      return;
    }
    run(async () => {
      await AssignmentApi.create(
        {
          title: assignment.title.trim(),
          description: assignment.description.trim() || undefined,
          courseId: Number(courseId),
          dueDate: localInputToIso(assignment.due),
        },
        assignment.file
      );
      setAssignment(emptyAssignment);
      setFileKey((k) => k + 1);
    });
  }

  function switchMode(next) {
    setMode(next);
    setError("");
  }

  return (
    <div className="card feed-composer">
      {canManage && (
        <div className="btn-group feed-composer-tabs">
          {[
            ["POST", "Post"],
            ["ANNOUNCEMENT", "Announcement"],
            ["ASSIGNMENT", "Assignment"],
          ].map(([key, label]) => (
            <button
              key={key}
              type="button"
              className={`btn btn-sm ${mode === key ? "btn-primary" : "btn-ghost"}`}
              onClick={() => switchMode(key)}
            >
              {label}
            </button>
          ))}
        </div>
      )}
      {error && <div className="banner banner-error">{error}</div>}

      {mode === "POST" && (
        <form onSubmit={submitPost}>
          <textarea
            rows="3"
            required
            maxLength={2000}
            placeholder="Share something with this course..."
            value={postText}
            onChange={(e) => setPostText(e.target.value)}
          />
          <div className="feed-composer-actions">
            <button className="btn btn-primary btn-sm" type="submit" disabled={busy || !postText.trim()}>
              {busy ? "Posting..." : "Post"}
            </button>
          </div>
        </form>
      )}

      {mode === "ANNOUNCEMENT" && canManage && (
        <form onSubmit={submitAnnouncement}>
          <label>Title</label>
          <input required value={announcement.title} onChange={(e) => setAnnouncement({ ...announcement, title: e.target.value })} />
          <label>Message</label>
          <textarea
            rows="3"
            required
            maxLength={2000}
            value={announcement.message}
            onChange={(e) => setAnnouncement({ ...announcement, message: e.target.value })}
          />
          <p className="form-hint">Everyone in this course is notified.</p>
          <div className="feed-composer-actions">
            <button className="btn btn-primary btn-sm" type="submit" disabled={busy}>
              {busy ? "Posting..." : "Post announcement"}
            </button>
          </div>
        </form>
      )}

      {mode === "ASSIGNMENT" && canManage && (
        <form onSubmit={submitAssignment}>
          <label>Title</label>
          <input required value={assignment.title} onChange={(e) => setAssignment({ ...assignment, title: e.target.value })} />
          <label>Instructions (optional)</label>
          <textarea
            rows="2"
            value={assignment.description}
            onChange={(e) => setAssignment({ ...assignment, description: e.target.value })}
          />
          <div className="form-row">
            <div>
              <label>Due</label>
              <input type="datetime-local" required value={assignment.due} onChange={(e) => setAssignment({ ...assignment, due: e.target.value })} />
            </div>
            <div>
              <label>Assignment PDF</label>
              <input
                key={fileKey}
                type="file"
                accept="application/pdf,.pdf"
                required
                onChange={(e) => setAssignment({ ...assignment, file: e.target.files?.[0] || null })}
              />
            </div>
          </div>
          <div className="feed-composer-actions">
            <button className="btn btn-primary btn-sm" type="submit" disabled={busy}>
              {busy ? "Uploading..." : "Post assignment"}
            </button>
          </div>
        </form>
      )}
    </div>
  );
}

// "You", "You and Bob", "You, Bob and 3 others" — same phrasing pattern most feeds use.
// `otherNames` is everyone who liked it besides the viewer (backend excludes the viewer from it);
// prepend "You" when the viewer themself liked it.
function likersSummary(otherNames, likedByMe) {
  const list = likedByMe ? ["You", ...otherNames] : otherNames;
  if (list.length === 1) return list[0];
  if (list.length === 2) return `${list[0]} and ${list[1]}`;
  if (list.length === 3) return `${list[0]}, ${list[1]} and ${list[2]}`;
  return `${list[0]}, ${list[1]} and ${list.length - 2} others`;
}

function PostItem({ post, canDelete, onLike, onDelete }) {
  const otherNames = post.likerNames || [];
  return (
    <div className="card feed-item">
      <div className="feed-item-head">
        <span className="pill">Post</span>
        <strong>{post.authorName}</strong>
        <span className="pill role-pill small">{post.authorRole}</span>
        <span className="feed-item-time">{fmtDateTime(post.createdAt)}</span>
      </div>
      <p className="feed-item-body">{post.content}</p>
      <div className="feed-item-foot">
        <div className="feed-item-likes">
          <button
            type="button"
            className={`like-btn ${post.likedByMe ? "liked" : ""}`}
            aria-pressed={post.likedByMe}
            onClick={() => onLike(post)}
          >
            {post.likedByMe ? "♥" : "♡"} {post.likeCount > 0 ? post.likeCount : ""} <span>{post.likedByMe ? "Liked" : "Like"}</span>
          </button>
          {post.likeCount > 0 && (
            <span className="feed-item-like-names" title={(post.likedByMe ? ["You", ...otherNames] : otherNames).join(", ")}>
              Liked by {likersSummary(otherNames, post.likedByMe)}
            </span>
          )}
        </div>
        {canDelete && (
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => onDelete(post)}>
            Delete
          </button>
        )}
      </div>
    </div>
  );
}

function AnnouncementItem({ item, canDelete, onDelete }) {
  return (
    <div className="card feed-item feed-item-announcement">
      <div className="feed-item-head">
        <span className="pill status-warn">Announcement</span>
        <strong>{item.createdByName}</strong>
        <span className="pill role-pill small">{item.createdByRole}</span>
        <span className="feed-item-time">{fmtDateTime(item.createdAt)}</span>
      </div>
      <div className="card-title feed-item-title">{item.title}</div>
      <p className="feed-item-body">{item.message}</p>
      {canDelete && (
        <div className="feed-item-foot">
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => onDelete(item)}>
            Delete
          </button>
        </div>
      )}
    </div>
  );
}

function AssignmentItem({ item }) {
  const { user } = useAuth();
  // Students hand work in; the assignment's author (or any admin) reviews and grades it.
  const canReview = user.role === "ADMIN" || item.teacherId === user.id;
  return (
    <div className="card feed-item feed-item-assignment">
      <div className="feed-item-head">
        <span className="pill status-ok">Assignment</span>
        <strong>{item.teacherName}</strong>
        <span className="pill role-pill small">{item.authorRole}</span>
        <span className="feed-item-time">{fmtDateTime(item.createdAt)}</span>
      </div>
      <div className="card-title feed-item-title">{item.title}</div>
      {item.description && <p className="feed-item-body">{item.description}</p>}
      <div className="card-sub">Due {fmtDateTime(item.dueDate)}</div>
      <ResumePreview url={item.attachmentUrl} label="assignment" />
      {user.role === "STUDENT" && <StudentSubmission assignment={item} />}
      {canReview && <TeacherSubmissions assignment={item} />}
    </div>
  );
}

// The course stream: posts, announcements and assignments in one date-ordered feed that can be
// filtered by type and by a from/to date range (calendar days in IST, on when each item was added).
export default function CourseFeed({ courseId, canManage }) {
  const { user } = useAuth();
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [typeFilter, setTypeFilter] = useState("ALL");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const load = useCallback(async () => {
    try {
      const [posts, announcements, assignments] = await Promise.all([
        PostApi.forCourse(courseId),
        AnnouncementApi.forCourse(courseId),
        AssignmentApi.forCourse(courseId),
      ]);
      setData({ posts, announcements, assignments });
      setError("");
    } catch (err) {
      setError(err.message);
    }
  }, [courseId]);

  useEffect(() => {
    load();
  }, [load]);

  const items = useMemo(() => {
    if (!data) return [];
    return [
      ...data.posts.map((p) => ({ kind: "POST", key: `p${p.id}`, createdAt: p.createdAt, data: p })),
      ...data.announcements.map((a) => ({ kind: "ANNOUNCEMENT", key: `a${a.id}`, createdAt: a.createdAt, data: a })),
      ...data.assignments.map((a) => ({ kind: "ASSIGNMENT", key: `s${a.id}`, createdAt: a.createdAt, data: a })),
    ].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  }, [data]);

  const groups = useMemo(() => {
    const visible = items.filter((it) => {
      if (typeFilter !== "ALL" && it.kind !== typeFilter) return false;
      const day = toDateInputValue(new Date(it.createdAt));
      if (from && day < from) return false;
      if (to && day > to) return false;
      return true;
    });
    const byDay = new Map();
    visible.forEach((it) => {
      const day = toDateInputValue(new Date(it.createdAt));
      if (!byDay.has(day)) byDay.set(day, { day, label: fmtDate(it.createdAt), items: [] });
      byDay.get(day).items.push(it);
    });
    return Array.from(byDay.values());
  }, [items, typeFilter, from, to]);

  const visibleCount = groups.reduce((n, g) => n + g.items.length, 0);
  const filtered = typeFilter !== "ALL" || from || to;

  async function like(post) {
    try {
      const updated = await PostApi.toggleLike(post.id);
      setData((d) => ({ ...d, posts: d.posts.map((p) => (p.id === updated.id ? updated : p)) }));
    } catch (err) {
      setError(err.message);
    }
  }

  async function removePost(post) {
    if (!confirm("Delete this post?")) return;
    try {
      await PostApi.delete(post.id);
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function removeAnnouncement(a) {
    if (!confirm("Delete this announcement? This can't be undone.")) return;
    try {
      await AnnouncementApi.delete(a.id);
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  function clearFilters() {
    setTypeFilter("ALL");
    setFrom("");
    setTo("");
  }

  return (
    <div className="course-feed">
      <Composer courseId={courseId} canManage={canManage} onPosted={load} />

      <div className="card feed-filters">
        <div className="btn-group feed-type-filter">
          {TYPE_FILTERS.map((f) => (
            <button
              key={f.key}
              type="button"
              className={`btn btn-sm ${typeFilter === f.key ? "btn-primary" : "btn-ghost"}`}
              onClick={() => setTypeFilter(f.key)}
            >
              {f.label}
            </button>
          ))}
        </div>
        <div className="feed-date-filter">
          <label>
            From
            <input type="date" value={from} max={to || undefined} onChange={(e) => setFrom(e.target.value)} />
          </label>
          <label>
            To
            <input type="date" value={to} min={from || undefined} onChange={(e) => setTo(e.target.value)} />
          </label>
          {filtered && (
            <button type="button" className="btn btn-ghost btn-sm" onClick={clearFilters}>
              Clear filters
            </button>
          )}
        </div>
      </div>

      {error && <div className="banner banner-error">{error}</div>}
      {!data && !error && <p className="card-sub">Loading...</p>}
      {data && visibleCount === 0 && (
        <p className="empty-state">{filtered ? "Nothing matches these filters." : "Nothing here yet — be the first to post."}</p>
      )}

      {groups.map((g) => (
        <div className="feed-day" key={g.day}>
          <h3 className="feed-day-heading">{g.label}</h3>
          <div className="card-list">
            {g.items.map((it) => {
              if (it.kind === "POST") {
                return (
                  <PostItem
                    key={it.key}
                    post={it.data}
                    canDelete={user.role === "ADMIN" || it.data.authorId === user.id}
                    onLike={like}
                    onDelete={removePost}
                  />
                );
              }
              if (it.kind === "ANNOUNCEMENT") {
                return (
                  <AnnouncementItem
                    key={it.key}
                    item={it.data}
                    canDelete={user.role === "ADMIN" || (user.role === "TEACHER" && it.data.createdById === user.id)}
                    onDelete={removeAnnouncement}
                  />
                );
              }
              return <AssignmentItem key={it.key} item={it.data} />;
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
