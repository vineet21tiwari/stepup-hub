import { useEffect, useMemo, useState } from "react";
import { CoordinatorApi, CourseApi, UserApi } from "../../api/endpoints";

// Course-level coordinator assignment (replaces the old per-class-session picker): pick a course on
// the left, manage its coordinators on the right. The list below answers "which courses is each
// coordinator assigned to" without having to click through every course.
export default function AdminCoordinators() {
  const [courses, setCourses] = useState([]);
  const [allCoordinators, setAllCoordinators] = useState([]);
  const [selectedCourse, setSelectedCourse] = useState(null);
  const [assigned, setAssigned] = useState([]);
  const [picked, setPicked] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [coursesByCoordinator, setCoursesByCoordinator] = useState({}); // { [coordinatorId]: CourseDto[] | "loading" }

  useEffect(() => {
    CourseApi.list().then(setCourses);
    UserApi.byRole("COORDINATOR").then(setAllCoordinators);
  }, []);

  useEffect(() => {
    allCoordinators.forEach((c) => {
      setCoursesByCoordinator((prev) => (prev[c.id] ? prev : { ...prev, [c.id]: "loading" }));
      CoordinatorApi.coursesFor(c.id).then((list) => setCoursesByCoordinator((prev) => ({ ...prev, [c.id]: list })));
    });
  }, [allCoordinators]);

  async function selectCourse(course) {
    setSelectedCourse(course);
    setError("");
    setPicked("");
    setAssigned(await CourseApi.coordinatorsForCourse(course.id));
  }

  async function refreshAfterChange() {
    setAssigned(await CourseApi.coordinatorsForCourse(selectedCourse.id));
    // Assignment counts shown below may now be stale for the affected coordinator — just refetch all.
    allCoordinators.forEach((c) => CoordinatorApi.coursesFor(c.id).then((list) => setCoursesByCoordinator((prev) => ({ ...prev, [c.id]: list }))));
  }

  async function assign() {
    if (!picked) return;
    setBusy(true);
    setError("");
    try {
      await CourseApi.assignCoordinator(selectedCourse.id, picked);
      setPicked("");
      await refreshAfterChange();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function unassign(coordinatorId) {
    setBusy(true);
    setError("");
    try {
      await CourseApi.unassignCoordinator(selectedCourse.id, coordinatorId);
      await refreshAfterChange();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  const availableToAssign = useMemo(
    () => allCoordinators.filter((c) => !assigned.some((a) => a.id === c.id)),
    [allCoordinators, assigned]
  );

  return (
    <div className="page">
      <h1>Coordinator assignments</h1>
      <p className="page-subtitle">Assign one or more coordinators to a course — they cover every class in it.</p>

      <div className="browse-grid">
        <div className="browse-col">
          <h3>Courses</h3>
          <div className="list-select">
            {courses.map((c) => (
              <button
                key={c.id}
                className={`list-select-item ${selectedCourse?.id === c.id ? "active" : ""}`}
                onClick={() => selectCourse(c)}
              >
                <div className="list-select-title">{c.title}</div>
                {c.subject && <div className="list-select-sub">{c.subject}</div>}
              </button>
            ))}
            {courses.length === 0 && <p className="empty-state">No courses yet.</p>}
          </div>
        </div>

        <div className="browse-col">
          <h3>Coordinators{selectedCourse ? ` — ${selectedCourse.title}` : ""}</h3>
          {!selectedCourse && <p className="empty-state">Select a course to manage its coordinators.</p>}
          {selectedCourse && (
            <>
              {error && <div className="banner banner-error">{error}</div>}
              <div className="card-list">
                {assigned.map((c) => (
                  <div className="card" key={c.id}>
                    <div className="card-row">
                      <div className="card-row-main">
                        <div className="card-title">{c.name}</div>
                        <div className="card-sub">{c.email}</div>
                      </div>
                      <button className="btn btn-ghost btn-sm" disabled={busy} onClick={() => unassign(c.id)}>
                        Remove
                      </button>
                    </div>
                  </div>
                ))}
                {assigned.length === 0 && <p className="empty-state">No coordinators assigned yet.</p>}
              </div>

              {availableToAssign.length > 0 && (
                <div className="btn-group admin-coordinators-add-row">
                  <select value={picked} onChange={(e) => setPicked(e.target.value)}>
                    <option value="">Select a coordinator</option>
                    {availableToAssign.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                  <button className="btn btn-primary btn-sm" disabled={!picked || busy} onClick={assign}>
                    Assign
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </div>

      <div className="section">
        <h2>All coordinators</h2>
        <div className="card-list">
          {allCoordinators.map((c) => {
            const list = coursesByCoordinator[c.id];
            return (
              <div className="card" key={c.id}>
                <div className="card-title">{c.name}</div>
                <div className="card-sub">{c.email}</div>
                <div className="card-sub">
                  {list === "loading" || list === undefined
                    ? "Loading..."
                    : list.length === 0
                    ? "Not assigned to any course yet"
                    : `Assigned to: ${list.map((course) => course.title).join(", ")}`}
                </div>
              </div>
            );
          })}
          {allCoordinators.length === 0 && <p className="empty-state">No coordinator accounts yet — create one under Users.</p>}
        </div>
      </div>
    </div>
  );
}
