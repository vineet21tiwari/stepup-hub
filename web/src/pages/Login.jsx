import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import logo from "../assets/logo.png";
import { roleHome } from "../utils/roleHome";
import ThemeToggle from "../components/ThemeToggle";

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function onSubmit(e) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const me = await login(email, password);
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
      <div className="auth-card">
        <img src={logo} alt="StepUp Hub" className="auth-logo" />
        <h1>Welcome back</h1>
        <p className="auth-subtitle">Step Up in Studies, Step Ahead with Confidence</p>
        {error && <div className="banner banner-error">{error}</div>}
        <form onSubmit={onSubmit}>
          <label>Email</label>
          <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" />
          <label>Password</label>
          <input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} placeholder="••••••••" />
          <br></br>
          <p className="auth-forgot">
            <Link to="/forgot-password">Forgot password?</Link>
          </p>
          <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
            {busy ? "Signing in..." : "Log in"}
          </button>
        </form>
        <p className="auth-footer">
          New here? <Link to="/signup">Create an account</Link>
        </p>
        <p className="auth-hint">Demo admin: admin@stepuphub.com / Admin@123</p>
      </div>
    </div>
  );
}
