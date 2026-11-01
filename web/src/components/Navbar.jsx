import { NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import logo from "../assets/logo.png";
import NotificationBell from "./NotificationBell";
import NavDropdown from "./NavDropdown";
import ThemeToggle from "./ThemeToggle";

const LINKS_BY_ROLE = {
  STUDENT: [
    { to: "/student", label: "Dashboard" },
    { to: "/student/courses", label: "Courses" },
    { to: "/student/bookings", label: "My Bookings" },
    { to: "/sessions", label: "My Classes" },
  ],
  TEACHER: [
    { to: "/teacher", label: "Dashboard" },
    { to: "/teacher/courses", label: "Courses" },
    { to: "/teacher/slots", label: "My Slots" },
    { to: "/teacher/approvals", label: "Booking Requests" },
    { to: "/sessions", label: "My Classes" },
  ],
  COORDINATOR: [
    { to: "/coordinator", label: "Dashboard" },
    { to: "/sessions", label: "My Classes" },
    { to: "/coordinator/messages", label: "Message Admin" },
    { to: "/coordinator/tasks", label: "My Tasks" },
  ],
  ADMIN: [
    { to: "/admin", label: "Dashboard" },
    {
      label: "Manage",
      children: [
        { to: "/admin/courses", label: "Courses" },
        { to: "/admin/users", label: "Users" },
        { to: "/admin/coordinators", label: "Coordinators" },
        { to: "/admin/teacher-applications", label: "Teacher Applications" },
        { to: "/admin/bookings", label: "Booking Approvals" },
      ],
    },
    {
      label: "Content",
      children: [
        { to: "/admin/announcements", label: "Announcements" },
        { to: "/admin/site-content", label: "Website Content" },
      ],
    },
    {
      label: "Coordinators",
      children: [
        { to: "/admin/coordinator-messages", label: "Messages" },
        { to: "/admin/tasks", label: "Tasks" },
      ],
    },
    { to: "/sessions", label: "My Classes" },
  ],
};

export default function Navbar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  if (!user) return null;
  const links = LINKS_BY_ROLE[user.role] || [];

  return (
    <header className="navbar">
      <div className="navbar-inner">
        <div className="navbar-brand">
          <img src={logo} alt="StepUp Hub" />
        </div>
        <nav className="navbar-links">
          {links.map((l) =>
            l.children ? (
              <NavDropdown key={l.label} label={l.label} items={l.children} />
            ) : (
              <NavLink key={l.to} to={l.to} className={({ isActive }) => (isActive ? "active" : "")}>
                {l.label}
              </NavLink>
            )
          )}
        </nav>
        <div className="navbar-right">
          <ThemeToggle />
          <NotificationBell />
          <div className="navbar-user">
            <span className="navbar-user-name">{user.name}</span>
            <span className="pill role-pill">{user.role}</span>
          </div>
          <button
            className="btn btn-ghost"
            onClick={() => {
              logout();
              navigate("/login");
            }}
          >
            Log out
          </button>
        </div>
      </div>
    </header>
  );
}
