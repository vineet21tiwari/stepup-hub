import { createContext, useContext, useEffect, useState } from "react";
import { AuthApi, UserApi } from "../api/endpoints";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem("stepup_token");
    if (!token) {
      setLoading(false);
      return;
    }
    UserApi.me()
      .then((me) => setUser(me))
      .catch(() => {
        localStorage.removeItem("stepup_token");
      })
      .finally(() => setLoading(false));
  }, []);

  async function login(email, password) {
    const res = await AuthApi.login({ email, password });
    localStorage.setItem("stepup_token", res.token);
    const me = await UserApi.me();
    setUser(me);
    return me;
  }

  async function signup(payload, resumeFile) {
    const res = await AuthApi.signup(payload, resumeFile);
    localStorage.setItem("stepup_token", res.token);
    const me = await UserApi.me();
    setUser(me);
    return me;
  }

  function logout() {
    localStorage.removeItem("stepup_token");
    setUser(null);
  }

  return (
    <AuthContext.Provider value={{ user, loading, login, signup, logout, setUser }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
