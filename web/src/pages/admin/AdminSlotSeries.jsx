import { useEffect, useMemo, useState } from "react";
import { TeacherApi } from "../../api/endpoints";
import { fmtDate } from "../../utils/format";

// Admin: every teacher's active weekly slot series. Unlike teachers (who can only remove empty
// slots), admin can cancel a whole series including booked slots — the booked classes are
// cancelled and every affected student and the teacher are notified.
export default function AdminSlotSeries() {
  const [series, setSeries] = useState(null);
  const [query, setQuery] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [message, setMessage] = useState(null);

  async function load() {
    try {
      setSeries(await TeacherApi.allSeries());
    } catch (err) {
      setMessage({ kind: "error", text: err.message });
      setSeries([]);
    }
  }

  useEffect(() => {
    load();
  }, []);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return (series || []).filter((s) => !q || s.teacherName.toLowerCase().includes(q) || s.courseTitle.toLowerCase().includes(q));
  }, [series, query]);

  async function cancel(s) {
    const warn = s.bookedSlots > 0
      ? `${s.bookedSlots} slot(s) in this series are booked. Their classes will be cancelled and students notified. Continue?`
      : "Cancel every slot in this series?";
    if (!confirm(warn)) return;
    setBusyId(s.recurrenceGroupId);
    setMessage(null);
    try {
      const res = await TeacherApi.adminCancelSeries(s.recurrenceGroupId);
      setMessage({ kind: "info", text: `Cancelled ${res.cancelled} slot(s)${res.bookedCancelled ? `, including ${res.bookedCancelled} booked` : ""}.` });
      await load();
    } catch (err) {
      setMessage({ kind: "error", text: err.message });
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="page">
      <h1>Slot series</h1>
      <p className="page-subtitle">Cancel a teacher's weekly slot series, including slots students have already booked.</p>

      {message && <div className={`banner banner-${message.kind}`}>{message.text}</div>}
      <input className="search-input" placeholder="Search by teacher or course" value={query} onChange={(e) => setQuery(e.target.value)} />

      {series === null ? (
        <div className="page-loading">Loading...</div>
      ) : filtered.length === 0 ? (
        <p className="empty-state">No active slot series.</p>
      ) : (
        <div className="card-list">
          {filtered.map((s) => (
            <div className="card" key={s.recurrenceGroupId}>
              <div className="card-row card-row-stack">
                <div className="card-row-main">
                  <div className="card-title">
                    {s.courseTitle}
                    <span className="pill small">{s.sessionType === "GROUP" ? "Group" : "1-on-1"}</span>
                  </div>
                  <div className="card-sub">Teacher: {s.teacherName}</div>
                  <div className="card-sub">
                    {fmtDate(s.firstStart)} → {fmtDate(s.lastStart)}
                  </div>
                  <div className="card-sub">
                    {s.totalSlots} slots · <strong>{s.bookedSlots} booked</strong>
                  </div>
                </div>
                <button className="btn btn-ghost btn-sm btn-danger-ghost" disabled={busyId === s.recurrenceGroupId} onClick={() => cancel(s)}>
                  {busyId === s.recurrenceGroupId ? "Cancelling..." : "Cancel series"}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
