import { useEffect, useMemo, useState } from "react";
import { TeacherApi, UserApi } from "../../api/endpoints";
import { fileUrl } from "../../utils/files";
import { useAuth } from "../../context/AuthContext";
import ResumePreview from "../../components/ResumePreview";

const ROLE_TABS = ["ALL", "STUDENT", "TEACHER", "COORDINATOR", "ADMIN"];

const emptyEditForm = { name: "", email: "", phone: "", extraInfo: "", approved: true };

// Admin provisions only these two roles directly — students/teachers self-signup instead.
const emptyCreateForm = { name: "", email: "", password: "", phone: "", role: "COORDINATOR", extraInfo: "" };

export default function AdminUsers() {
  const { user: me } = useAuth();
  const [users, setUsers] = useState([]);
  const [roleFilter, setRoleFilter] = useState("ALL");
  const [search, setSearch] = useState("");
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState(emptyEditForm);
  const [expandedTeacherId, setExpandedTeacherId] = useState(null);
  const [teacherApps, setTeacherApps] = useState({}); // { [teacherId]: appsArray | "loading" }
  const [busyId, setBusyId] = useState(null);
  const [error, setError] = useState("");
  const [creating, setCreating] = useState(false);
  const [createForm, setCreateForm] = useState(emptyCreateForm);
  const [createBusy, setCreateBusy] = useState(false);
  const [createError, setCreateError] = useState("");
  const [resetResult, setResetResult] = useState(null); // { userId, name, tempPassword }

  async function load() {
    setUsers(await UserApi.byRole());
  }

  useEffect(() => {
    load();
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return users.filter((u) => {
      if (roleFilter !== "ALL" && u.role !== roleFilter) return false;
      if (!q) return true;
      return u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q);
    });
  }, [users, roleFilter, search]);

  function startEdit(u) {
    setError("");
    setEditingId(u.id);
    setEditForm({ name: u.name, email: u.email, phone: u.phone || "", extraInfo: u.extraInfo || "", approved: u.approved });
  }

  function cancelEdit() {
    setEditingId(null);
    setEditForm(emptyEditForm);
  }

  async function saveEdit(u) {
    setBusyId(u.id);
    setError("");
    try {
      await UserApi.update(u.id, {
        name: editForm.name,
        email: editForm.email,
        phone: editForm.phone,
        extraInfo: editForm.extraInfo,
        approved: u.role === "TEACHER" ? editForm.approved : undefined,
      });
      cancelEdit();
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId(null);
    }
  }

  async function toggleActive(u) {
    if (u.active && !confirm(`Deactivate ${u.name}? They won't be able to log in, and teachers will disappear from booking until reactivated.`)) {
      return;
    }
    setBusyId(u.id);
    setError("");
    try {
      if (u.active) await UserApi.deactivate(u.id);
      else await UserApi.reactivate(u.id);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId(null);
    }
  }

  async function toggleExpand(u) {
    if (expandedTeacherId === u.id) {
      setExpandedTeacherId(null);
      return;
    }
    setExpandedTeacherId(u.id);
    if (!teacherApps[u.id]) {
      setTeacherApps((prev) => ({ ...prev, [u.id]: "loading" }));
      try {
        const apps = await TeacherApi.applicationsForTeacher(u.id);
        setTeacherApps((prev) => ({ ...prev, [u.id]: apps }));
      } catch {
        setTeacherApps((prev) => ({ ...prev, [u.id]: [] }));
      }
    }
  }

  async function submitCreate(e) {
    e.preventDefault();
    setCreateBusy(true);
    setCreateError("");
    try {
      await UserApi.create(createForm);
      setCreateForm(emptyCreateForm);
      setCreating(false);
      await load();
    } catch (err) {
      setCreateError(err.message);
    } finally {
      setCreateBusy(false);
    }
  }

  async function doResetPassword(u) {
    if (!confirm(`Reset ${u.name}'s password? Their current password will stop working immediately.`)) return;
    setBusyId(u.id);
    setError("");
    try {
      const result = await UserApi.resetPassword(u.id);
      setResetResult({ userId: u.id, name: u.name, tempPassword: result.tempPassword });
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="page">
      <h1>Users</h1>
      <p className="page-subtitle">Every account on the platform — inspect teacher resumes/intro videos/courses, edit profiles, or deactivate an account.</p>

      {error && <div className="banner banner-error">{error}</div>}

      {resetResult && (
        <div className="banner banner-info admin-users-reset-banner">
          <span>
            New temporary password for <strong>{resetResult.name}</strong>: <code>{resetResult.tempPassword}</code> — share it
            with them now, it won't be shown again.
          </span>
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => setResetResult(null)}>
            Dismiss
          </button>
        </div>
      )}

      <div className="section-header">
        <h2>Create Admin / Coordinator account</h2>
        <button type="button" className="btn btn-ghost btn-sm" onClick={() => setCreating((c) => !c)}>
          {creating ? "Cancel" : "+ New account"}
        </button>
      </div>

      {creating && (
        <form className="card form-card admin-users-create-form" onSubmit={submitCreate}>
          {createError && <div className="banner banner-error">{createError}</div>}
          <div className="form-row">
            <div>
              <label>Full name</label>
              <input required value={createForm.name} onChange={(e) => setCreateForm((f) => ({ ...f, name: e.target.value }))} />
            </div>
            <div>
              <label>Role</label>
              <select value={createForm.role} onChange={(e) => setCreateForm((f) => ({ ...f, role: e.target.value }))}>
                <option value="COORDINATOR">Coordinator</option>
                <option value="ADMIN">Admin</option>
              </select>
            </div>
          </div>
          <div className="form-row">
            <div>
              <label>Email</label>
              <input type="email" required value={createForm.email} onChange={(e) => setCreateForm((f) => ({ ...f, email: e.target.value }))} />
            </div>
            <div>
              <label>Phone</label>
              <input value={createForm.phone} onChange={(e) => setCreateForm((f) => ({ ...f, phone: e.target.value }))} />
            </div>
          </div>
          <label>Initial password</label>
          <input
            type="password"
            required
            minLength={6}
            value={createForm.password}
            onChange={(e) => setCreateForm((f) => ({ ...f, password: e.target.value }))}
          />
          <label>Title (optional)</label>
          <input value={createForm.extraInfo} onChange={(e) => setCreateForm((f) => ({ ...f, extraInfo: e.target.value }))} />
          <button className="btn btn-primary" type="submit" disabled={createBusy}>
            {createBusy ? "Creating..." : "Create account"}
          </button>
        </form>
      )}

      <div className="admin-users-toolbar">
        <div className="btn-group slot-mode-toggle">
          {ROLE_TABS.map((r) => (
            <button key={r} type="button" className={`btn btn-sm ${roleFilter === r ? "btn-primary" : "btn-ghost"}`} onClick={() => setRoleFilter(r)}>
              {r === "ALL" ? "All" : r.charAt(0) + r.slice(1).toLowerCase()}
            </button>
          ))}
        </div>
        <input
          className="admin-users-search"
          placeholder="Search by name or email..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="card-list">
        {filtered.map((u) => (
          <div className="card" key={u.id}>
            <div className="card-row">
              <div className="card-row-main">
                <div className="card-title" title={u.name}>
                  {u.name}
                  <span className="pill small role-pill">{u.role}</span>
                  {u.role === "TEACHER" && <span className={`pill small status-${u.approved ? "ok" : "warn"}`}>{u.approved ? "Approved" : "Not approved"}</span>}
                  {!u.active && <span className="pill small status-bad">Deactivated</span>}
                </div>
                <div className="card-sub">{u.email}{u.phone ? ` · ${u.phone}` : ""}</div>
                {u.extraInfo && <div className="card-sub">{u.extraInfo}</div>}
              </div>
              <div className="btn-group">
                {u.role === "TEACHER" && (
                  <button className="btn btn-ghost btn-sm" onClick={() => toggleExpand(u)}>
                    {expandedTeacherId === u.id ? "Hide details" : "View details"}
                  </button>
                )}
                <button className="btn btn-ghost btn-sm" onClick={() => (editingId === u.id ? cancelEdit() : startEdit(u))}>
                  {editingId === u.id ? "Cancel" : "Edit"}
                </button>
                <button className="btn btn-ghost btn-sm" disabled={busyId === u.id} onClick={() => doResetPassword(u)}>
                  Reset password
                </button>
                <button
                  className="btn btn-ghost btn-sm"
                  disabled={busyId === u.id || (u.id === me.id && u.active)}
                  title={u.id === me.id && u.active ? "You can't deactivate your own account" : undefined}
                  onClick={() => toggleActive(u)}
                >
                  {u.active ? "Deactivate" : "Reactivate"}
                </button>
              </div>
            </div>

            {editingId === u.id && (
              <div className="admin-users-edit-form">
                <div className="form-row">
                  <div>
                    <label>Name</label>
                    <input value={editForm.name} onChange={(e) => setEditForm((f) => ({ ...f, name: e.target.value }))} />
                  </div>
                  <div>
                    <label>Email</label>
                    <input type="email" value={editForm.email} onChange={(e) => setEditForm((f) => ({ ...f, email: e.target.value }))} />
                  </div>
                </div>
                <div className="form-row">
                  <div>
                    <label>Phone</label>
                    <input value={editForm.phone} onChange={(e) => setEditForm((f) => ({ ...f, phone: e.target.value }))} />
                  </div>
                  <div>
                    <label>{u.role === "TEACHER" ? "Qualification" : "Extra info"}</label>
                    <input value={editForm.extraInfo} onChange={(e) => setEditForm((f) => ({ ...f, extraInfo: e.target.value }))} />
                  </div>
                </div>
                {u.role === "TEACHER" && (
                  <label className="admin-users-checkbox">
                    <input type="checkbox" checked={editForm.approved} onChange={(e) => setEditForm((f) => ({ ...f, approved: e.target.checked }))} />
                    Approved teacher (can be listed and booked platform-wide)
                  </label>
                )}
                <button className="btn btn-primary btn-sm" disabled={busyId === u.id} onClick={() => saveEdit(u)}>
                  {busyId === u.id ? "Saving..." : "Save changes"}
                </button>
              </div>
            )}

            {u.role === "TEACHER" && expandedTeacherId === u.id && (
              <div className="admin-users-details">
                <div className="admin-users-detail-row">
                  <span className="card-sub">Resume:</span>
                  <ResumePreview url={u.resumeUrl} />
                </div>
                <div className="card-sub" style={{ marginTop: 10 }}>
                  Course applications:
                </div>
                {teacherApps[u.id] === "loading" && <p className="empty-state">Loading...</p>}
                {Array.isArray(teacherApps[u.id]) && teacherApps[u.id].length === 0 && (
                  <p className="empty-state">No course applications yet.</p>
                )}
                {Array.isArray(teacherApps[u.id]) && (
                  <div className="admin-users-app-grid">
                    {teacherApps[u.id].map((a) => (
                      <div className="admin-users-app-card" key={a.applicationId}>
                        <div className="card-row">
                          <span className="card-title">{a.courseTitle}</span>
                          <span className={`pill small status-${a.status === "APPROVED" ? "ok" : a.status === "REJECTED" ? "bad" : "warn"}`}>{a.status}</span>
                        </div>
                        {a.introVideoUrl ? (
                          <video src={fileUrl(a.introVideoUrl)} controls className="video-capture-preview" />
                        ) : (
                          <span className="card-sub">No intro video for this course</span>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
        {filtered.length === 0 && <p className="empty-state">No users match.</p>}
      </div>
    </div>
  );
}
