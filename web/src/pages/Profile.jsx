import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import PasswordInput from "../components/PasswordInput";
import { initials } from "../utils/format";

const EXTRA_LABEL = {
  STUDENT: "Grade / education level",
  TEACHER: "Qualification & experience",
  COORDINATOR: "About you",
  ADMIN: "About you",
};

// Every user can edit their own name, email, phone, short bio and password here.
export default function Profile() {
  const { user, updateProfile } = useAuth();
  const [form, setForm] = useState({ name: "", email: "", phone: "", extraInfo: "" });
  const [pw, setPw] = useState({ current: "", next: "", confirm: "" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [saved, setSaved] = useState("");

  useEffect(() => {
    if (!user) return;
    setForm({ name: user.name || "", email: user.email || "", phone: user.phone || "", extraInfo: user.extraInfo || "" });
  }, [user]);

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
    setSaved("");
  }

  async function submit(e) {
    e.preventDefault();
    setError("");
    setSaved("");
    const changingPassword = pw.next || pw.current || pw.confirm;
    if (changingPassword) {
      if (!pw.current) return setError("Enter your current password to set a new one.");
      if (pw.next.length < 6) return setError("New password must be at least 6 characters.");
      if (pw.next !== pw.confirm) return setError("New password and confirmation don't match.");
    }
    setBusy(true);
    try {
      await updateProfile({
        name: form.name.trim(),
        email: form.email.trim(),
        phone: form.phone.trim() || null,
        extraInfo: form.extraInfo.trim() || null,
        currentPassword: changingPassword ? pw.current : null,
        newPassword: changingPassword ? pw.next : null,
      });
      setPw({ current: "", next: "", confirm: "" });
      setSaved(changingPassword ? "Profile and password updated." : "Profile updated.");
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (!user) return null;

  return (
    <div className="page">
      <div className="profile-header">
        <div className="profile-avatar">{initials(user.name)}</div>
        <div>
          <h1>{user.name}</h1>
          <span className="pill role-pill">{user.role}</span>
        </div>
      </div>

      <form className="card form-card profile-form" onSubmit={submit}>
        {error && <div className="banner banner-error">{error}</div>}
        {saved && <div className="banner banner-info">{saved}</div>}

        <h2 className="profile-section-title">Edit profile</h2>
        <div className="form-row">
          <div>
            <label>Full name</label>
            <input required value={form.name} onChange={(e) => update("name", e.target.value)} />
          </div>
          <div>
            <label>Phone</label>
            <input type="tel" value={form.phone} onChange={(e) => update("phone", e.target.value)} />
          </div>
        </div>
        <label>Email</label>
        <input type="email" required value={form.email} onChange={(e) => update("email", e.target.value)} />
        <label>{EXTRA_LABEL[user.role] || "About you"}</label>
        <textarea rows="2" value={form.extraInfo} onChange={(e) => update("extraInfo", e.target.value)} />

        <h2 className="profile-section-title">Change password</h2>
        <p className="form-hint">Leave blank to keep your current password.</p>
        <label>Current password</label>
        <PasswordInput autoComplete="current-password" value={pw.current} onChange={(e) => setPw((p) => ({ ...p, current: e.target.value }))} />
        <div className="form-row">
          <div>
            <label>New password</label>
            <PasswordInput autoComplete="new-password" value={pw.next} onChange={(e) => setPw((p) => ({ ...p, next: e.target.value }))} />
          </div>
          <div>
            <label>Confirm new password</label>
            <PasswordInput autoComplete="new-password" value={pw.confirm} onChange={(e) => setPw((p) => ({ ...p, confirm: e.target.value }))} />
          </div>
        </div>

        <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
          {busy ? "Saving..." : "Save changes"}
        </button>
      </form>
    </div>
  );
}
