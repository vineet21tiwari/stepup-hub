import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { CourseApi, TeacherApi } from "../../api/endpoints";
import { statusColor } from "../../utils/format";
import { fileUrl } from "../../utils/files";
import VideoCapture from "../../components/VideoCapture";

export default function TeacherCourses() {
  const [courses, setCourses] = useState([]);
  const [applications, setApplications] = useState([]);
  const [applying, setApplying] = useState(null);
  const [error, setError] = useState("");
  const [applyVideos, setApplyVideos] = useState({}); // courseId -> File, for the apply step
  const [videoEditing, setVideoEditing] = useState({}); // applicationId -> bool, "add/replace video" open
  const [laterVideos, setLaterVideos] = useState({}); // applicationId -> File
  const [savingVideo, setSavingVideo] = useState(null);
  const [cancelling, setCancelling] = useState(null);

  async function load() {
    const [c, a] = await Promise.all([CourseApi.list(), TeacherApi.myApplications()]);
    setCourses(c);
    setApplications(a);
  }

  useEffect(() => {
    load();
  }, []);

  function applicationFor(courseId) {
    return applications.find((a) => a.courseId === courseId);
  }

  async function apply(courseId) {
    setApplying(courseId);
    setError("");
    try {
      await TeacherApi.apply(courseId, applyVideos[courseId] || null);
      setApplyVideos((v) => ({ ...v, [courseId]: null }));
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setApplying(null);
    }
  }

  async function cancelApplication(applicationId) {
    if (!confirm("Withdraw this application? You can re-apply later if you change your mind.")) return;
    setCancelling(applicationId);
    setError("");
    try {
      await TeacherApi.cancelApplication(applicationId);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setCancelling(null);
    }
  }

  async function saveLaterVideo(applicationId) {
    const file = laterVideos[applicationId];
    if (!file) return;
    setSavingVideo(applicationId);
    setError("");
    try {
      await TeacherApi.addApplicationVideo(applicationId, file);
      setLaterVideos((v) => ({ ...v, [applicationId]: null }));
      setVideoEditing((v) => ({ ...v, [applicationId]: false }));
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setSavingVideo(null);
    }
  }

  return (
    <div className="page">
      <h1>Courses</h1>
      <p className="page-subtitle">Apply to teach a course. Admin reviews and approves each application.</p>
      {error && <div className="banner banner-error">{error}</div>}

      <div className="card-list">
        {courses.map((c) => {
          const app = applicationFor(c.id);
          return (
            <div className="card" key={c.id}>
              <div className="card-row">
                <div className="card-row-main">
                  <div className="card-title" title={c.title}>{c.title}</div>
                  {c.subject && <div className="card-sub">{c.subject}</div>}
                  {c.description && <div className="card-sub">{c.description}</div>}
                  <Link to={`/courses/${c.id}`} className="card-sub">
                    View announcements
                  </Link>
                </div>
                {app ? (
                  <div className="btn-group">
                    <span className={`pill status-${statusColor(app.status)}`}>{app.status}</span>
                    {app.status === "PENDING" && (
                      <button className="btn btn-ghost btn-sm" disabled={cancelling === app.id} onClick={() => cancelApplication(app.id)}>
                        {cancelling === app.id ? "Withdrawing..." : "Withdraw"}
                      </button>
                    )}
                  </div>
                ) : (
                  <button className="btn btn-primary btn-sm" disabled={applying === c.id} onClick={() => apply(c.id)}>
                    {applying === c.id ? "Applying..." : "Apply to teach"}
                  </button>
                )}
              </div>

              {!app && (
                <div className="apply-video-section">
                  <label>Intro video (optional)</label>
                  <p className="form-hint">A short clip students can watch when picking a teacher for this course.</p>
                  <VideoCapture
                    file={applyVideos[c.id] || null}
                    onChange={(f) => setApplyVideos((v) => ({ ...v, [c.id]: f }))}
                  />
                </div>
              )}

              {app && (
                <div className="apply-video-section">
                  {app.introVideoUrl && !videoEditing[app.id] && (
                    <>
                      <video src={fileUrl(app.introVideoUrl)} controls className="video-capture-preview" />
                      <button
                        className="btn btn-ghost btn-sm"
                        onClick={() => setVideoEditing((v) => ({ ...v, [app.id]: true }))}
                      >
                        Replace video
                      </button>
                    </>
                  )}
                  {!app.introVideoUrl && !videoEditing[app.id] && (
                    <button
                      className="btn btn-ghost btn-sm"
                      onClick={() => setVideoEditing((v) => ({ ...v, [app.id]: true }))}
                    >
                      Add intro video
                    </button>
                  )}
                  {videoEditing[app.id] && (
                    <>
                      <VideoCapture
                        file={laterVideos[app.id] || null}
                        onChange={(f) => setLaterVideos((v) => ({ ...v, [app.id]: f }))}
                      />
                      <div className="btn-group">
                        <button
                          className="btn btn-primary btn-sm"
                          disabled={!laterVideos[app.id] || savingVideo === app.id}
                          onClick={() => saveLaterVideo(app.id)}
                        >
                          {savingVideo === app.id ? "Saving..." : "Save video"}
                        </button>
                        <button
                          className="btn btn-ghost btn-sm"
                          onClick={() => setVideoEditing((v) => ({ ...v, [app.id]: false }))}
                        >
                          Cancel
                        </button>
                      </div>
                    </>
                  )}
                </div>
              )}
            </div>
          );
        })}
        {courses.length === 0 && <p className="empty-state">No courses have been created yet.</p>}
      </div>
    </div>
  );
}
