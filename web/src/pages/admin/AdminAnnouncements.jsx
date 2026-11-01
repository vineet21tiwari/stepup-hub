import { useEffect, useState } from "react";
import { AnnouncementApi, CourseApi } from "../../api/endpoints";
import { fmtDateTime } from "../../utils/format";

const emptyForm = { title: "", message: "", scope: "GLOBAL", courseId: "" };

export default function AdminAnnouncements() {
  const [announcements, setAnnouncements] = useState([]);
  const [courses, setCourses] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function load() {
    setAnnouncements(await AnnouncementApi.all());
  }

  useEffect(() => {
    load();
    CourseApi.list().then(setCourses);
  }, []);

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  function startEdit(a) {
    setEditingId(a.id);
    setError("");
    setForm({ title: a.title, message: a.message, scope: a.scope, courseId: a.courseId || "" });
  }

  function cancelEdit() {
    setEditingId(null);
    setError("");
    setForm(emptyForm);
  }

  async function save(e) {
    e.preventDefault();
    setError("");
    if (form.scope === "COURSE" && !form.courseId) {
      setError("Choose a course for a course-scoped announcement.");
      return;
    }
    setBusy(true);
    const payload = {
      title: form.title,
      message: form.message,
      scope: form.scope,
      courseId: form.scope === "COURSE" ? Number(form.courseId) : undefined,
    };
    try {
      if (editingId) {
        await AnnouncementApi.update(editingId, payload);
        setEditingId(null);
      } else {
        await AnnouncementApi.create(payload);
      }
      setForm(emptyForm);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function remove(id) {
    if (!confirm("Delete this announcement? This can't be undone.")) return;
    try {
      await AnnouncementApi.delete(id);
      if (editingId === id) cancelEdit();
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      <h1>Announcements</h1>
      <p className="page-subtitle">Post a global announcement for everyone, or a course-scoped one for its teachers, students, and coordinators.</p>

      <form className="card form-card" onSubmit={save}>
        {error && <div className="banner banner-error">{error}</div>}
        <label>Title</label>
        <input required value={form.title} onChange={(e) => update("title", e.target.value)} />
        <label>Message</label>
        <textarea rows="3" required value={form.message} onChange={(e) => update("message", e.target.value)} />
        <div className="form-row">
          <div>
            <label>Scope</label>
            {editingId ? (
              <input disabled value={form.scope === "COURSE" ? "Specific course" : "Global (everyone)"} />
            ) : (
              <select value={form.scope} onChange={(e) => update("scope", e.target.value)}>
                <option value="GLOBAL">Global (everyone)</option>
                <option value="COURSE">Specific course</option>
              </select>
            )}
          </div>
          {form.scope === "COURSE" && (
            <div>
              <label>Course</label>
              {editingId ? (
                <input disabled value={courses.find((c) => String(c.id) === String(form.courseId))?.title || ""} />
              ) : (
                <select value={form.courseId} onChange={(e) => update("courseId", e.target.value)}>
                  <option value="">Select course</option>
                  {courses.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.title}
                    </option>
                  ))}
                </select>
              )}
            </div>
          )}
        </div>
        <br></br>
        {editingId && <p className="form-hint">Scope and course can't be changed after posting — delete and repost if you need a different one.</p>}
        <div className="btn-group">
          <button className="btn btn-primary" type="submit" disabled={busy}>
            {busy ? "Saving..." : editingId ? "Save changes" : "Post announcement"}
          </button>
          {editingId && (
            <button type="button" className="btn btn-ghost" onClick={cancelEdit} disabled={busy}>
              Cancel
            </button>
          )}
        </div>
      </form>

      <div className="section">
        <h2>All announcements</h2>
        <div className="card-list">
          {announcements.map((a) => (
            <div className="card" key={a.id}>
              <div className="card-row">
                <div className="card-row-main">
                  <div className="card-title" title={a.title}>{a.title}</div>
                  <p className="card-sub">{a.message}</p>
                  <div className="card-sub">
                    {a.createdByName} · {fmtDateTime(a.createdAt)}
                  </div>
                </div>
                <div className="btn-group">
                  <span className="pill">{a.scope === "COURSE" ? a.courseTitle : "Global"}</span>
                  <button className="btn btn-ghost btn-sm" onClick={() => startEdit(a)}>
                    Edit
                  </button>
                  <button className="btn btn-ghost btn-sm" onClick={() => remove(a.id)}>
                    Delete
                  </button>
                </div>
              </div>
            </div>
          ))}
          {announcements.length === 0 && <p className="empty-state">No announcements posted yet.</p>}
        </div>
      </div>
    </div>
  );
}
