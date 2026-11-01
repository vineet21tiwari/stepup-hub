import { useEffect, useState } from "react";
import { EnrollmentApi } from "../../api/endpoints";
import { fmtTimeRange, groupEnrollmentRequests, statusColor } from "../../utils/format";

// Approval is a two-step (teacher, then admin) process internally, but a student just has one
// pending request — don't name either reviewer here.
const STATUS_LABEL = {
  PENDING_TEACHER: "Under review",
  PENDING_ADMIN: "Under review",
  APPROVED: "Confirmed",
  REJECTED_BY_TEACHER: "Declined",
  REJECTED_BY_ADMIN: "Declined",
};

const CANCELLABLE_STATUSES = ["PENDING_TEACHER", "PENDING_ADMIN"];

export default function MyBookings() {
  const [bookings, setBookings] = useState([]);
  const [cancelling, setCancelling] = useState(null);
  const [error, setError] = useState("");

  async function load() {
    setBookings(await EnrollmentApi.mine());
  }

  useEffect(() => {
    load();
  }, []);

  async function cancel(id) {
    if (!confirm("Cancel this booking request?")) return;
    setCancelling(id);
    setError("");
    try {
      await EnrollmentApi.cancel(id);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setCancelling(null);
    }
  }

  return (
    <div className="page">
      <h1>My booking requests</h1>
      {error && <div className="banner banner-error">{error}</div>}
      {bookings.length === 0 && <p className="empty-state">You haven't requested any classes yet.</p>}
      <div className="card-list">
        {groupEnrollmentRequests(
          bookings.slice().sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        ).map(({ representative: b, count }) => (
          <div className="card" key={b.id}>
            <div className="card-row">
              <div className="card-row-main">
                <div className="card-title" title={b.courseTitle}>
                  {b.courseTitle}
                  {count > 1 && <span className="pill small">{count} weekly classes</span>}
                </div>
                <div className="card-sub">with {b.teacherName}</div>
                <div className="card-sub">{fmtTimeRange(b.slotStart, b.slotEnd)}</div>
              </div>
              <div className="btn-group">
                <span className={`pill status-${statusColor(b.status)}`}>{STATUS_LABEL[b.status] || b.status}</span>
                {CANCELLABLE_STATUSES.includes(b.status) && (
                  <button className="btn btn-ghost btn-sm" disabled={cancelling === b.id} onClick={() => cancel(b.id)}>
                    {cancelling === b.id ? "Cancelling..." : "Cancel"}
                  </button>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
