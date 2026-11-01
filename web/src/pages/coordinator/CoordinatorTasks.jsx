import { useEffect, useState } from "react";
import { TaskApi } from "../../api/endpoints";
import { fmtDateTime } from "../../utils/format";
import TaskThread from "../../components/TaskThread";

const STATUS_LABEL = { PENDING: "Pending", IN_PROGRESS: "In progress", DONE: "Done" };

// Tasks an admin assigned to this coordinator, with a deadline and a per-task file-sharing thread.
export default function CoordinatorTasks() {
  const [tasks, setTasks] = useState([]);
  const [busyId, setBusyId] = useState(null);
  const [error, setError] = useState("");
  const [openTaskId, setOpenTaskId] = useState(null);

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

  return (
    <div className="page">
      <h1>My tasks</h1>
      <p className="page-subtitle">Tasks assigned to you by admin. Share files or ask questions in each task's thread.</p>
      {error && <div className="banner banner-error">{error}</div>}

      <div className="card-list">
        {tasks.map((t) => {
          const overdue = t.status !== "DONE" && new Date(t.deadline).getTime() < now;
          return (
            <div className="card" key={t.id}>
              <div className="card-row" onClick={() => setOpenTaskId(openTaskId === t.id ? null : t.id)} style={{ cursor: "pointer" }}>
                <div className="card-row-main">
                  <div className="card-title">
                    {t.title}
                    {t.courseTitle && <span className="pill small">{t.courseTitle}</span>}
                  </div>
                  <div className="card-sub">From {t.assignedByName}</div>
                  <div className={`card-sub ${overdue ? "task-overdue" : ""}`}>
                    Due {fmtDateTime(t.deadline)}
                    {overdue ? " · Overdue" : ""}
                  </div>
                </div>
                <select
                  value={t.status}
                  disabled={busyId === t.id}
                  onClick={(e) => e.stopPropagation()}
                  onChange={(e) => changeStatus(t.id, e.target.value)}
                >
                  {Object.entries(STATUS_LABEL).map(([value, label]) => (
                    <option key={value} value={value}>
                      {label}
                    </option>
                  ))}
                </select>
              </div>
              {openTaskId === t.id && (
                <div className="task-thread-wrap">
                  {t.description && <p className="card-sub">{t.description}</p>}
                  <TaskThread taskId={t.id} />
                </div>
              )}
            </div>
          );
        })}
        {tasks.length === 0 && <p className="empty-state">No tasks assigned to you yet.</p>}
      </div>
    </div>
  );
}
