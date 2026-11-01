import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import logo from "../assets/logo.png";
import { roleHome } from "../utils/roleHome";
import ThemeToggle from "../components/ThemeToggle";

// Coordinator and Admin accounts are created by an admin (see AdminUsers) — not self-signup.
const EXTRA_LABEL = {
  STUDENT: "Grade / education level (e.g. Grade 10)",
  TEACHER: "Qualification & experience (e.g. M.Sc Mathematics, 5 yrs experience)",
};

export default function Signup() {
  const { signup } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({
    name: "",
    email: "",
    password: "",
    phone: "",
    role: "STUDENT",
    extraInfo: "",
  });
  const [resume, setResume] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function onSubmit(e) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const me = await signup(form, form.role === "TEACHER" ? resume : null);
      navigate(roleHome(me.role));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth-screen">
      <div className="auth-screen-theme">
        <ThemeToggle />
      </div>
      <div className="auth-card auth-card-wide">
        <img src={logo} alt="StepUp Hub" className="auth-logo" />
        <h1>Create your account</h1>
        <br></br>
        {error && <div className="banner banner-error">{error}</div>}
        <form onSubmit={onSubmit}>
          <div className="form-row">
            <div>
              <label>Full name</label>
              <input required value={form.name} onChange={(e) => update("name", e.target.value)} />
            </div>
            <div>
              <label>I am a</label>
              <select value={form.role} onChange={(e) => update("role", e.target.value)}>
                <option value="STUDENT">Student</option>
                <option value="TEACHER">Teacher</option>
              </select>
            </div>
          </div>
          <div className="form-row">
            <div>
              <label>Email</label>
              <input type="email" required value={form.email} onChange={(e) => update("email", e.target.value)} />
            </div>
            <div>
              <label>Phone</label>
              <input value={form.phone} onChange={(e) => update("phone", e.target.value)} />
            </div>
          </div>
          <label>Password</label>
          <input
            type="password"
            required
            minLength={6}
            value={form.password}
            onChange={(e) => update("password", e.target.value)}
          />
          <label>{EXTRA_LABEL[form.role]}</label>
          <input value={form.extraInfo} onChange={(e) => update("extraInfo", e.target.value)} />
          {form.role === "TEACHER" && (
            <>
              <label>Resume (optional)</label>
              <input type="file" accept=".pdf,.doc,.docx" onChange={(e) => setResume(e.target.files?.[0] || null)} />
              <p className="form-hint">
                Teacher accounts need Admin approval before you can be listed and apply to courses. You can log in right away
                and track your status. You can attach your resume now or skip it for later.
              </p>
            </>
          )}
          <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
            {busy ? "Creating account..." : "Sign up"}
          </button>
        </form>
        <p className="auth-footer">
          Already have an account? <Link to="/login">Log in</Link>
        </p>
      </div>
    </div>
  );
}
