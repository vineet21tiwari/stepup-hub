import { useEffect, useState } from "react";
import { EnrollmentApi } from "../../api/endpoints";
import { fmtTimeRange, groupEnrollmentRequests } from "../../utils/format";

export default function AdminBookingApprovals() {
  const [requests, setRequests] = useState([]);
  const [busyId, setBusyId] = useState(null);

  async function load() {
    setRequests(await EnrollmentApi.pendingForAdmin());
  }

  useEffect(() => {
    load();
  }, []);

  async function decide(id, approve) {
    setBusyId(id);
    try {
      await EnrollmentApi.adminDecide(id, approve);
      await load();
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="page">
      <h1>Booking approvals</h1>
      <p className="page-subtitle">These bookings were already approved by the teacher. Approve to schedule the class.</p>
      {requests.length === 0 && <p className="empty-state">Nothing waiting on you right now.</p>}
      <div className="card-list">
        {groupEnrollmentRequests(requests).map(({ representative: r, count }) => (
          <div className="card" key={r.id}>
            <div className="card-row">
              <div className="card-row-main">
                <div className="card-title" title={`${r.studentName} → ${r.courseTitle}`}>
                  {r.studentName} → {r.courseTitle}
                  {count > 1 && <span className="pill small">{count} weekly classes</span>}
                </div>
                <div className="card-sub">Teacher: {r.teacherName}</div>
                <div className="card-sub">{fmtTimeRange(r.slotStart, r.slotEnd)}</div>
                <div className="card-sub">
                  Student: {r.studentEmail}
                  {r.studentPhone ? ` · ${r.studentPhone}` : ""}
                </div>
                {r.studentExtraInfo && <div className="card-sub">{r.studentExtraInfo}</div>}
              </div>
              <div className="btn-group">
                <button className="btn btn-primary btn-sm" disabled={busyId === r.id} onClick={() => decide(r.id, true)}>
                  Confirm class
                </button>
                <button className="btn btn-ghost btn-sm" disabled={busyId === r.id} onClick={() => decide(r.id, false)}>
                  Decline
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
