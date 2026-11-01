import { useEffect, useState } from "react";
import { EnrollmentApi } from "../../api/endpoints";
import { fmtTimeRange, groupEnrollmentRequests } from "../../utils/format";

export default function TeacherApprovals() {
  const [requests, setRequests] = useState([]);
  const [busyId, setBusyId] = useState(null);

  async function load() {
    setRequests(await EnrollmentApi.pendingForTeacher());
  }

  useEffect(() => {
    load();
  }, []);

  async function decide(id, approve) {
    setBusyId(id);
    try {
      await EnrollmentApi.teacherDecide(id, approve);
      await load();
    } finally {
      setBusyId(null);
    }
  }

  const groups = groupEnrollmentRequests(requests);

  return (
    <div className="page">
      <h1>Booking requests</h1>
      <p className="page-subtitle">Approve or decline students who booked your slots. Approved requests then go to Admin.</p>
      {groups.length === 0 && <p className="empty-state">No pending requests right now.</p>}
      <div className="card-list">
        {groups.map(({ representative: r, count }) => (
          <div className="card" key={r.id}>
            <div className="card-row">
              <div className="card-row-main">
                <div className="card-title" title={r.studentName}>{r.studentName}</div>
                <div className="card-sub">
                  {r.courseTitle}
                  {count > 1 && <span className="pill small">{count} weekly classes</span>}
                </div>
                <div className="card-sub">{fmtTimeRange(r.slotStart, r.slotEnd)}</div>
                <div className="card-sub">
                  {r.studentEmail}
                  {r.studentPhone ? ` · ${r.studentPhone}` : ""}
                </div>
                {r.studentExtraInfo && <div className="card-sub">{r.studentExtraInfo}</div>}
              </div>
              <div className="btn-group">
                <button className="btn btn-primary btn-sm" disabled={busyId === r.id} onClick={() => decide(r.id, true)}>
                  Approve
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
