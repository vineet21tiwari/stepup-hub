import { useState } from "react";
import { Link } from "react-router-dom";
import { AuthApi } from "../api/endpoints";
import logo from "../assets/logo.png";
import ThemeToggle from "../components/ThemeToggle";

export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  async function onSubmit(e) {
    e.preventDefault();
    setError("");
    if (newPassword !== confirmPassword) {
      setError("New password and confirm password don't match.");
      return;
    }
    setBusy(true);
    try {
      await AuthApi.forgotPassword({ email, newPassword, confirmPassword });
      setDone(true);
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
        <h1>Reset your password</h1>
        <p className="auth-subtitle">Enter your account email and a new password.</p>
        {error && <div className="banner banner-error">{error}</div>}
        {done ? (
          <>
            <div className="banner banner-info">Password reset. You can log in with your new password now.</div>
            <p className="auth-footer">
              <Link to="/login">Back to login</Link>
            </p>
          </>
        ) : (
          <form onSubmit={onSubmit}>
            <label>Email</label>
            <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" />
            <label>New password</label>
            <input
              type="password"
              required
              minLength={6}
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              placeholder="••••••••"
            />
            <label>Confirm new password</label>
            <input
              type="password"
              required
              minLength={6}
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="••••••••"
            />
            <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
              {busy ? "Resetting..." : "Reset password"}
            </button>
            <p className="auth-footer">
              <Link to="/login">Back to login</Link>
            </p>
          </form>
        )}
      </div>
    </div>
  );
}
