import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { CourseApi } from "../../api/endpoints";
import ResumePreview from "../../components/ResumePreview";

export default function AdminCourses() {
  const [courses, setCourses] = useState([]);
  const [form, setForm] = useState({ title: "", description: "", subject: "" });
  const [curriculum, setCurriculum] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function load() {
    setCourses(await CourseApi.list());
  }

  useEffect(() => {
    load();
  }, []);

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function create(e) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await CourseApi.create(form, curriculum);
      setForm({ title: "", description: "", subject: "" });
      setCurriculum(null);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function deactivate(id) {
    if (!confirm("Deactivate this course? It will no longer be visible to students or teachers.")) return;
    await CourseApi.deactivate(id);
    load();
  }

  return (
    <div className="page">
      <h1>Courses</h1>

      <form className="card form-card" onSubmit={create}>
        {error && <div className="banner banner-error">{error}</div>}
        <div className="form-row">
          <div>
            <label>Title</label>
            <input required value={form.title} onChange={(e) => update("title", e.target.value)} />
          </div>
          <div>
            <label>Subject</label>
            <input value={form.subject} onChange={(e) => update("subject", e.target.value)} />
          </div>
        </div>
        <label>Description</label>
        <textarea rows="2" value={form.description} onChange={(e) => update("description", e.target.value)} />
        <label>Curriculum brochure (optional PDF)</label>
        <input type="file" accept="application/pdf" onChange={(e) => setCurriculum(e.target.files?.[0] || null)} />
        <p className="form-hint">Students will be able to view this from the course page.</p>
        <button className="btn btn-primary" type="submit" disabled={busy}>
          {busy ? "Creating..." : "Create course"}
        </button>
      </form>

      <div className="section">
        <h2>All courses</h2>
        <div className="card-list">
          {courses.map((c) => (
            <div className="card" key={c.id}>
              <div className="card-row">
                <div className="card-row-main">
                  <div className="card-title" title={c.title}>{c.title}</div>
                  {c.subject && <div className="card-sub">{c.subject}</div>}
                  {c.description && <div className="card-sub">{c.description}</div>}
                  <Link to={`/courses/${c.id}`} className="card-sub">
                    View announcements
                  </Link>
                  {c.curriculumUrl && <ResumePreview url={c.curriculumUrl} label="curriculum" />}
                </div>
                <button className="btn btn-ghost btn-sm" onClick={() => deactivate(c.id)}>
                  Deactivate
                </button>
              </div>
            </div>
          ))}
          {courses.length === 0 && <p className="empty-state">No courses yet — create the first one above.</p>}
        </div>
      </div>
    </div>
  );
}
