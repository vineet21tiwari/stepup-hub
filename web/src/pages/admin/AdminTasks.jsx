import { useEffect, useState } from "react";
import { CourseApi, TaskApi, UserApi } from "../../api/endpoints";
import { fmtDateTime, isoToLocalInput, localInputToIso } from "../../utils/format";
import TaskThread from "../../components/TaskThread";

const STATUS_LABEL = { PENDING: "Pending", IN_PROGRESS: "In progress", DONE: "Done" };

const emptyForm = { title: "", description: "", courseId: "", coordinatorId: "", deadline: "" };

// Admin assigns tasks (with a deadline) to coordinators; a task can optionally be tied to a course.
// Tasks can be edited or deleted. Each task has its own file-sharing message thread (see TaskThread).
export default function AdminTasks() {
  const [tasks, setTasks] = useState([]);
  const [courses, setCourses] = useState([]);
  const [coordinators, setCoordinators] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [formOpen, setFormOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [openTaskId, setOpenTaskId] = useState(null);

  async function load() {
    setTasks(await TaskApi.mine());
  }

  useEffect(() => {
    load();
    CourseApi.list().then(setCourses);
    UserApi.byRole("COORDINATOR").then(setCoordinators);
  }, []);

  function startCreate() {
    setEditingId(null);
    setForm(emptyForm);
    setError("");
    setFormOpen(true);
  }

  function startEdit(t) {
    setEditingId(t.id);
    setForm({
      title: t.title,
      description: t.description || "",
      courseId: t.courseId ? String(t.courseId) : "",
      coordinatorId: String(t.coordinatorId),
      deadline: isoToLocalInput(t.deadline),
    });
    setError("");
    setFormOpen(true);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function closeForm() {
    setFormOpen(false);
    setEditingId(null);
    setForm(emptyForm);
  }

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const payload = {
      title: form.title.trim(),
      description: form.description.trim() || undefined,
      courseId: form.courseId ? Number(form.courseId) : undefined,
      coordinatorId: Number(form.coordinatorId),
      deadline: localInputToIso(form.deadline),
    };
    try {
      if (editingId) await TaskApi.update(editingId, payload);
      else await TaskApi.create(payload);
      closeForm();
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function remove(t) {
    if (!confirm(`Delete the task "${t.title}"? Its messages and files will be removed too.`)) return;
    try {
      await TaskApi.delete(t.id);
      if (editingId === t.id) closeForm();
      await load();
    } catch (err) {
      alert(err.message);
    }
  }

  return (
    <div className="page">
      <h1>Tasks</h1>
      <p className="page-subtitle">Assign tasks to coordinators with a deadline — share files in each task's thread.</p>

      <div className="section-header">
        <h2>Assigned tasks</h2>
        <button type="button" className="btn btn-primary btn-sm" onClick={formOpen ? closeForm : startCreate}>
          {formOpen ? "Close" : "+ New task"}
        </button>
      </div>

      {formOpen && (
        <form className="card form-card admin-users-create-form" onSubmit={submit}>
          <h3 className="form-card-title">{editingId ? "Edit task" : "New task"}</h3>
          {error && <div className="banner banner-error">{error}</div>}
          <label>Title</label>
          <input required value={form.title} onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))} />
          <label>Description (optional)</label>
          <textarea rows="3" value={form.description} onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))} />
          <div className="form-row">
            <div>
              <label>Course (optional)</label>
              <select value={form.courseId} onChange={(e) => setForm((f) => ({ ...f, courseId: e.target.value }))}>
                <option value="">No specific course</option>
                {courses.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.title}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label>Coordinator</label>
              <select required value={form.coordinatorId} onChange={(e) => setForm((f) => ({ ...f, coordinatorId: e.target.value }))}>
                <option value="">Select coordinator</option>
                {coordinators.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <label>Deadline</label>
          <input type="datetime-local" required value={form.deadline} onChange={(e) => setForm((f) => ({ ...f, deadline: e.target.value }))} />
          <div className="btn-group btn-group-wrap form-actions">
            <button className="btn btn-primary" type="submit" disabled={busy}>
              {busy ? "Saving..." : editingId ? "Save changes" : "Assign task"}
            </button>
            <button className="btn btn-ghost" type="button" onClick={closeForm}>
              Cancel
            </button>
          </div>
        </form>
      )}

      <div className="card-list">
        {tasks.map((t) => (
          <div className={`card ${editingId === t.id ? "card-highlight" : ""}`} key={t.id}>
            <div className="card-row card-row-stack">
              <div className="card-row-main" onClick={() => setOpenTaskId(openTaskId === t.id ? null : t.id)} style={{ cursor: "pointer" }}>
                <div className="card-title">
                  {t.title}
                  {t.courseTitle && <span className="pill small">{t.courseTitle}</span>}
                </div>
                <div className="card-sub">Assigned to {t.coordinatorName}</div>
                <div className="card-sub">Due {fmtDateTime(t.deadline)}</div>
              </div>
              <div className="card-actions">
                <span className={`pill status-${t.status === "DONE" ? "ok" : t.status === "IN_PROGRESS" ? "warn" : ""}`}>
                  {STATUS_LABEL[t.status]}
                </span>
                <button className="btn btn-ghost btn-sm" onClick={() => startEdit(t)}>
                  Edit
                </button>
                <button className="btn btn-ghost btn-sm btn-danger-ghost" onClick={() => remove(t)}>
                  Delete
                </button>
              </div>
            </div>
            {openTaskId === t.id && (
              <div className="task-thread-wrap">
                {t.description && <p className="card-sub">{t.description}</p>}
                <TaskThread taskId={t.id} />
              </div>
            )}
            {openTaskId !== t.id && (
              <button className="link-btn" onClick={() => setOpenTaskId(t.id)}>
                Open messages & files
              </button>
            )}
          </div>
        ))}
        {tasks.length === 0 && <p className="empty-state">No tasks assigned yet.</p>}
      </div>
    </div>
  );
}
