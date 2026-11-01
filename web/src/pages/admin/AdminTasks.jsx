import { useEffect, useState } from "react";
import { CourseApi, TaskApi, UserApi } from "../../api/endpoints";
import { fmtDateTime, localInputToIso } from "../../utils/format";
import TaskThread from "../../components/TaskThread";

const STATUS_LABEL = { PENDING: "Pending", IN_PROGRESS: "In progress", DONE: "Done" };

const emptyForm = { title: "", description: "", courseId: "", coordinatorId: "", deadline: "" };

// Admin assigns tasks (with a deadline) to coordinators; a task can optionally be tied to a course.
// Each task has its own file-sharing message thread (see TaskThread).
export default function AdminTasks() {
  const [tasks, setTasks] = useState([]);
  const [courses, setCourses] = useState([]);
  const [coordinators, setCoordinators] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [creating, setCreating] = useState(false);
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

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await TaskApi.create({
        title: form.title.trim(),
        description: form.description.trim() || undefined,
        courseId: form.courseId ? Number(form.courseId) : undefined,
        coordinatorId: Number(form.coordinatorId),
        deadline: localInputToIso(form.deadline),
      });
      setForm(emptyForm);
      setCreating(false);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="page">
      <h1>Tasks</h1>
      <p className="page-subtitle">Assign tasks to coordinators with a deadline — share files in each task's thread.</p>

      <div className="section-header">
        <h2>Assigned tasks</h2>
        <button type="button" className="btn btn-ghost btn-sm" onClick={() => setCreating((c) => !c)}>
          {creating ? "Cancel" : "+ New task"}
        </button>
      </div>

      {creating && (
        <form className="card form-card admin-users-create-form" onSubmit={submit}>
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
          <button className="btn btn-primary" type="submit" disabled={busy}>
            {busy ? "Creating..." : "Assign task"}
          </button>
        </form>
      )}

      <div className="card-list">
        {tasks.map((t) => (
          <div className="card" key={t.id}>
            <div className="card-row" onClick={() => setOpenTaskId(openTaskId === t.id ? null : t.id)} style={{ cursor: "pointer" }}>
              <div className="card-row-main">
                <div className="card-title">
                  {t.title}
                  {t.courseTitle && <span className="pill small">{t.courseTitle}</span>}
                </div>
                <div className="card-sub">Assigned to {t.coordinatorName}</div>
                <div className="card-sub">Due {fmtDateTime(t.deadline)}</div>
              </div>
              <span className={`pill status-${t.status === "DONE" ? "ok" : t.status === "IN_PROGRESS" ? "warn" : ""}`}>
                {STATUS_LABEL[t.status]}
              </span>
            </div>
            {openTaskId === t.id && (
              <div className="task-thread-wrap">
                {t.description && <p className="card-sub">{t.description}</p>}
                <TaskThread taskId={t.id} />
              </div>
            )}
          </div>
        ))}
        {tasks.length === 0 && <p className="empty-state">No tasks assigned yet.</p>}
      </div>
    </div>
  );
}
