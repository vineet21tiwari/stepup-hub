import { useEffect, useMemo, useState } from "react";
import { SessionApi } from "../api/endpoints";
import { useAuth } from "../context/AuthContext";
import { ChangeRequestCard } from "../components/ClassChangePanel";

// Reschedule / cancel requests across all of the viewer's classes (admins see every one).
export default function ChangeRequests() {
  const { user } = useAuth();
  const [requests, setRequests] = useState(null);
  const [tab, setTab] = useState("action");

  async function load() {
    try {
      setRequests(await SessionApi.myChangeRequests());
    } catch {
      setRequests([]);
    }
  }

  useEffect(() => {
    load();
  }, []);

  const groups = useMemo(() => {
    const list = requests || [];
    return {
      action: list.filter((r) => r.canDecide),
      pending: list.filter((r) => r.status === "PENDING" && !r.canDecide),
      history: list.filter((r) => r.status !== "PENDING"),
    };
  }, [requests]);

  const shown = groups[tab];

  return (
    <div className="page">
      <h1>{user?.role === "ADMIN" ? "Class change requests" : "Change requests"}</h1>
      <p className="page-subtitle">
        Reschedule or cancellation requests for classes. Teacher requests need the student(s) and an admin to approve; student
        requests need the teacher and an admin. Changes are allowed only up to the day before the class.
      </p>

      <div className="segmented">
        {[
          ["action", `Needs your approval (${groups.action.length})`],
          ["pending", `Waiting on others (${groups.pending.length})`],
          ["history", "History"],
        ].map(([key, label]) => (
          <button key={key} className={`segmented-btn ${tab === key ? "active" : ""}`} onClick={() => setTab(key)}>
            {label}
          </button>
        ))}
      </div>

      {requests === null ? (
        <div className="page-loading">Loading...</div>
      ) : shown.length === 0 ? (
        <p className="empty-state">Nothing here.</p>
      ) : (
        <div className="card-list">
          {shown.map((r) => (
            <div className="card" key={r.id}>
              <ChangeRequestCard r={r} showClass onChanged={load} />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
