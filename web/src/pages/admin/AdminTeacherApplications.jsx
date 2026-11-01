import { useEffect, useState } from "react";
import { TeacherApi } from "../../api/endpoints";
import { fileUrl } from "../../utils/files";
import ResumePreview from "../../components/ResumePreview";

export default function AdminTeacherApplications() {
  const [applications, setApplications] = useState([]);
  const [busyId, setBusyId] = useState(null);

  async function load() {
    setApplications(await TeacherApi.pendingApplications());
  }

  useEffect(() => {
    load();
  }, []);

  async function decide(id, approve) {
    setBusyId(id);
    try {
      await TeacherApi.decideApplication(id, approve);
      await load();
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="page">
      <h1>Teacher applications</h1>
      <p className="page-subtitle">Approving a teacher's first course also activates their teacher profile platform-wide.</p>
      {applications.length === 0 && <p className="empty-state">No applications pending review.</p>}
      <div className="card-list">
        {applications.map((a) => (
          <div className="card" key={a.id}>
            <div className="card-row">
              <div className="card-row-main">
                <div className="card-title" title={a.teacherName}>{a.teacherName}</div>
                {a.teacherExtraInfo && <div className="card-sub">{a.teacherExtraInfo}</div>}
                <div className="card-sub">Applying to teach: {a.courseTitle}</div>
                <ResumePreview url={a.resumeUrl} />
                {a.introVideoUrl ? (
                  <video src={fileUrl(a.introVideoUrl)} controls className="video-capture-preview" />
                ) : (
                  <div className="teacher-media-empty">No intro video submitted</div>
                )}
              </div>
              <div className="btn-group">
                <button className="btn btn-primary btn-sm" disabled={busyId === a.id} onClick={() => decide(a.id, true)}>
                  Approve
                </button>
                <button className="btn btn-ghost btn-sm" disabled={busyId === a.id} onClick={() => decide(a.id, false)}>
                  Reject
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
