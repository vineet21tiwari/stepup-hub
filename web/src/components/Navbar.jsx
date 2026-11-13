import { useEffect, useState } from "react";
import { Link, NavLink, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import logo from "../assets/logo.png";
import NotificationBell from "./NotificationBell";
import NavDropdown from "./NavDropdown";
import ThemeToggle from "./ThemeToggle";
import { initials } from "../utils/format";

const LINKS_BY_ROLE = {
  STUDENT: [
    { to: "/student", label: "Dashboard", icon: "home" },
    { to: "/student/courses", label: "Courses", icon: "book" },
    { to: "/student/bookings", label: "My Bookings", icon: "ticket" },
    { to: "/sessions", label: "My Classes", icon: "calendar" },
    { to: "/change-requests", label: "Change Requests", icon: "swap" },
  ],
  TEACHER: [
    { to: "/teacher", label: "Dashboard", icon: "home" },
    { to: "/teacher/courses", label: "Courses", icon: "book" },
    { to: "/teacher/slots", label: "My Slots", icon: "clock" },
    { to: "/teacher/approvals", label: "Booking Requests", icon: "inbox" },
    { to: "/sessions", label: "My Classes", icon: "calendar" },
    { to: "/change-requests", label: "Change Requests", icon: "swap" },
  ],
  COORDINATOR: [
    { to: "/coordinator", label: "Dashboard", icon: "home" },
    { to: "/sessions", label: "My Classes", icon: "calendar" },
    { to: "/coordinator/messages", label: "Message Admin", icon: "chat" },
    { to: "/coordinator/tasks", label: "My Tasks", icon: "check" },
  ],
  ADMIN: [
    { to: "/admin", label: "Dashboard", icon: "home" },
    {
      label: "Manage",
      children: [
        { to: "/admin/courses", label: "Courses" },
        { to: "/admin/users", label: "Users" },
        { to: "/admin/coordinators", label: "Coordinators" },
        { to: "/admin/teacher-applications", label: "Teacher Applications" },
        { to: "/admin/bookings", label: "Booking Approvals" },
        { to: "/admin/slot-series", label: "Slot Series" },
        { to: "/change-requests", label: "Class Change Requests" },
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
    { to: "/sessions", label: "Classes", icon: "calendar" },
  ],
};

// Bottom tab bar on phones: the role's most-used screens. Everything else lives in the menu drawer.
const TABS_BY_ROLE = {
  STUDENT: [
    { to: "/student", label: "Home", icon: "home" },
    { to: "/student/courses", label: "Courses", icon: "book" },
    { to: "/sessions", label: "Classes", icon: "calendar" },
    { to: "/student/bookings", label: "Bookings", icon: "ticket" },
  ],
  TEACHER: [
    { to: "/teacher", label: "Home", icon: "home" },
    { to: "/teacher/slots", label: "Slots", icon: "clock" },
    { to: "/sessions", label: "Classes", icon: "calendar" },
    { to: "/teacher/approvals", label: "Requests", icon: "inbox" },
  ],
  COORDINATOR: [
    { to: "/coordinator", label: "Home", icon: "home" },
    { to: "/sessions", label: "Classes", icon: "calendar" },
    { to: "/coordinator/tasks", label: "Tasks", icon: "check" },
    { to: "/coordinator/messages", label: "Messages", icon: "chat" },
  ],
  ADMIN: [
    { to: "/admin", label: "Home", icon: "home" },
    { to: "/sessions", label: "Classes", icon: "calendar" },
    { to: "/admin/bookings", label: "Approvals", icon: "inbox" },
    { to: "/admin/tasks", label: "Tasks", icon: "check" },
  ],
};

const ICON_PATHS = {
  home: "M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z",
  book: "M4 4.5A2.5 2.5 0 0 1 6.5 2H20v17H6.5A2.5 2.5 0 0 0 4 21.5zM4 21.5A2.5 2.5 0 0 1 6.5 19H20v3H6.5",
  calendar: "M3 6a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM3 10h18M8 2v4M16 2v4",
  ticket: "M3 7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v3a2 2 0 0 0 0 4v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-3a2 2 0 0 0 0-4zM13 5v14",
  clock: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2",
  inbox: "M22 12h-6l-2 3h-4l-2-3H2M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z",
  chat: "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z",
  check: "M9 11l3 3L22 4M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11",
  swap: "M17 1l4 4-4 4M3 11V9a4 4 0 0 1 4-4h14M7 23l-4-4 4-4M21 13v2a4 4 0 0 1-4 4H3",
  menu: "M3 6h18M3 12h18M3 18h18",
  user: "M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z",
  logout: "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9",
  close: "M18 6 6 18M6 6l12 12",
  dot: "M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2z",
};

export function Icon({ name, size = 22 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={ICON_PATHS[name] || ICON_PATHS.dot} />
    </svg>
  );
}

export default function Navbar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [drawerOpen, setDrawerOpen] = useState(false);

  // Close the drawer whenever the route changes.
  useEffect(() => setDrawerOpen(false), [location.pathname]);

  useEffect(() => {
    document.body.classList.toggle("no-scroll", drawerOpen);
    return () => document.body.classList.remove("no-scroll");
  }, [drawerOpen]);

  if (!user) return null;
  const links = LINKS_BY_ROLE[user.role] || [];
  const tabs = TABS_BY_ROLE[user.role] || [];

  function doLogout() {
    logout();
    navigate("/login");
  }

  return (
    <>
      <header className="navbar">
        <div className="navbar-inner">
          <button className="navbar-menu-btn" onClick={() => setDrawerOpen(true)} aria-label="Open menu">
            <Icon name="menu" />
          </button>
          <Link to="/" className="navbar-brand" aria-label="StepUp Hub home">
            <img src={logo} alt="StepUp Hub" className="brand-logo" />
            <span className="navbar-brand-text">
              StepUp <span>Hub</span>
            </span>
          </Link>
          <nav className="navbar-links">
            {links.map((l) =>
              l.children ? (
                <NavDropdown key={l.label} label={l.label} items={l.children} />
              ) : (
                <NavLink key={l.to} to={l.to} end className={({ isActive }) => (isActive ? "active" : "")}>
                  {l.label}
                </NavLink>
              )
            )}
          </nav>
          <div className="navbar-right">
            <span className="navbar-desktop-only">
              <ThemeToggle />
            </span>
            <NotificationBell />
            <Link to="/profile" className="navbar-profile" title="Edit profile">
              <span className="avatar-circle">{initials(user.name)}</span>
              <span className="navbar-user">
                <span className="navbar-user-name">{user.name}</span>
                <span className="pill role-pill small">{user.role}</span>
              </span>
            </Link>
            <button className="btn btn-ghost btn-sm navbar-desktop-only" onClick={doLogout}>
              Log out
            </button>
          </div>
        </div>
      </header>

      {/* Phone: slide-in menu with every link */}
      <div className={`drawer-backdrop ${drawerOpen ? "open" : ""}`} onClick={() => setDrawerOpen(false)} />
      <aside className={`drawer ${drawerOpen ? "open" : ""}`} aria-hidden={!drawerOpen}>
        <div className="drawer-head">
          <img src={logo} alt="StepUp Hub" className="brand-logo brand-logo-lg" />
          <button className="drawer-close" onClick={() => setDrawerOpen(false)} aria-label="Close menu">
            <Icon name="close" />
          </button>
        </div>
        <Link to="/profile" className="drawer-user">
          <span className="avatar-circle avatar-lg">{initials(user.name)}</span>
          <span className="drawer-user-info">
            <strong>{user.name}</strong>
            <span>{user.email}</span>
            <span className="drawer-user-edit">Edit profile ›</span>
          </span>
        </Link>
        <nav className="drawer-nav">
          {links.map((l) =>
            l.children ? (
              <div key={l.label} className="drawer-group">
                <div className="drawer-group-label">{l.label}</div>
                {l.children.map((c) => (
                  <NavLink key={c.to} to={c.to} end className={({ isActive }) => `drawer-link ${isActive ? "active" : ""}`}>
                    <Icon name="dot" size={18} />
                    {c.label}
                  </NavLink>
                ))}
              </div>
            ) : (
              <NavLink key={l.to} to={l.to} end className={({ isActive }) => `drawer-link ${isActive ? "active" : ""}`}>
                <Icon name={l.icon} size={20} />
                {l.label}
              </NavLink>
            )
          )}
          <NavLink to="/profile" className={({ isActive }) => `drawer-link ${isActive ? "active" : ""}`}>
            <Icon name="user" size={20} />
            My Profile
          </NavLink>
        </nav>
        <div className="drawer-foot">
          <div className="drawer-theme">
            <span>Theme</span>
            <ThemeToggle />
          </div>
          <button className="btn btn-ghost btn-block" onClick={doLogout}>
            <Icon name="logout" size={18} /> Log out
          </button>
        </div>
      </aside>

      {/* Phone: bottom tab bar */}
      <nav className="bottom-nav" aria-label="Primary">
        {tabs.map((t) => (
          <NavLink key={t.to} to={t.to} end className={({ isActive }) => `bottom-nav-item ${isActive ? "active" : ""}`}>
            <Icon name={t.icon} />
            <span>{t.label}</span>
          </NavLink>
        ))}
        <button className={`bottom-nav-item ${drawerOpen ? "active" : ""}`} onClick={() => setDrawerOpen(true)}>
          <Icon name="menu" />
          <span>More</span>
        </button>
      </nav>
    </>
  );
}
