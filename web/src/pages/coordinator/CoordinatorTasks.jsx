import { useEffect, useState } from "react";
import { TaskApi } from "../../api/endpoints";
import { fmtDateTime } from "../../utils/format";
import TaskThread from "../../components/TaskThread";

const STATUS_LABEL = { PENDING: "Pending", IN_PROGRESS: "In progress", DONE: "Done" };
const STATUS_CLASS = { PENDING: "", IN_PROGRESS: "status-warn", DONE: "status-ok" };

// Tasks an admin assigned to this coordinator, with a deadline and a per-task file-sharing thread.
export default function CoordinatorTasks() {
  const [tasks, setTasks] = useState([]);
  const [busyId, setBusyId] = useState(null);
  const [error, setError] = useState("");
  const [openTaskId, setOpenTaskId] = useState(null);
  const [filter, setFilter] = useState("OPEN");

  async function load() {
    setTasks(await TaskApi.mine());
  }

  useEffect(() => {
    load();
  }, []);

  async function changeStatus(id, status) {
    setBusyId(id);
    setError("");
    try {
      await TaskApi.updateStatus(id, status);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId(null);
    }
  }

  const now = Date.now();
  const sorted = tasks.slice().sort((a, b) => new Date(a.deadline) - new Date(b.deadline));
  const open = sorted.filter((t) => t.status !== "DONE");
  const done = sorted.filter((t) => t.status === "DONE");
  const shown = filter === "OPEN" ? open : filter === "DONE" ? done : sorted;

  return (
    <div className="page">
      <h1>My tasks</h1>
      <p className="page-subtitle">Tasks assigned to you by admin. Share files or ask questions in each task's thread.</p>
      {error && <div className="banner banner-error">{error}</div>}

      <div className="segmented">
        {[
          ["OPEN", `To do (${open.length})`],
          ["DONE", `Done (${done.length})`],
          ["ALL", "All"],
        ].map(([key, label]) => (
          <button key={key} className={`segmented-btn ${filter === key ? "active" : ""}`} onClick={() => setFilter(key)}>
            {label}
          </button>
        ))}
      </div>

      <div className="card-list">
        {shown.map((t) => {
          const overdue = t.status !== "DONE" && new Date(t.deadline).getTime() < now;
          const isOpen = openTaskId === t.id;
          return (
            <div className={`card task-card ${overdue ? "task-card-overdue" : ""}`} key={t.id}>
              <div className="task-card-head">
                <h3 className="task-card-title">{t.title}</h3>
                <span className={`pill ${STATUS_CLASS[t.status]}`}>{STATUS_LABEL[t.status]}</span>
              </div>

              <div className="task-card-meta">
                <span>
                  <strong>From</strong> {t.assignedByName}
                </span>
                <span className={overdue ? "task-overdue" : ""}>
                  <strong>Due</strong> {fmtDateTime(t.deadline)}
                  {overdue && <span className="pill small status-bad task-overdue-pill">Overdue</span>}
                </span>
                {t.courseTitle && (
                  <span>
                    <strong>Course</strong> {t.courseTitle}
                  </span>
                )}
              </div>

              {t.description && <p className="task-card-desc">{t.description}</p>}

              <div className="task-card-foot">
                <div className="segmented task-status-switch" role="group" aria-label="Update status">
                  {Object.entries(STATUS_LABEL).map(([value, label]) => (
                    <button
                      key={value}
                      type="button"
                      disabled={busyId === t.id}
                      className={`segmented-btn ${t.status === value ? "active" : ""}`}
                      onClick={() => t.status !== value && changeStatus(t.id, value)}
                    >
                      {label}
                    </button>
                  ))}
                </div>
                <button className="btn btn-ghost btn-sm" onClick={() => setOpenTaskId(isOpen ? null : t.id)}>
                  {isOpen ? "Hide messages" : "Messages & files"}
                </button>
              </div>

              {isOpen && (
                <div className="task-thread-wrap">
                  <TaskThread taskId={t.id} />
                </div>
              )}
            </div>
          );
        })}
        {shown.length === 0 && (
          <p className="empty-state">{tasks.length === 0 ? "No tasks assigned to you yet." : "Nothing in this list."}</p>
        )}
      </div>
    </div>
  );
}
