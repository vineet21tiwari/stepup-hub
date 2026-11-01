import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AnnouncementApi, AssignmentApi, NotificationApi } from "../api/endpoints";
import { subscribeToUserNotifications } from "../api/socket";
import { useAuth } from "../context/AuthContext";
import { fmtDateTime } from "../utils/format";
import { roleHome } from "../utils/roleHome";

// Resolves a notification's `relatedEntity` pointer (e.g. "SESSION:12") to a route to open on click.
async function resolveRoute(notification, role) {
  const [entityType, entityId] = (notification.relatedEntity || "").split(":");
  switch (entityType) {
    case "SESSION":
      return `/sessions/${entityId}`;
    case "COURSE":
      return `/courses/${entityId}`;
    case "ENROLLMENT_REQUEST":
      if (role === "ADMIN") return "/admin/bookings";
      if (role === "TEACHER") return "/teacher/approvals";
      return "/student/bookings";
    case "TEACHER_APPLICATION":
      return role === "ADMIN" ? "/admin/teacher-applications" : "/teacher/courses";
    case "ANNOUNCEMENT": {
      // Announcement notifications only carry the announcement id, so look it up to find
      // whether it's course-scoped (route to that course) or global (route home, where the banner shows it).
      try {
        const a = await AnnouncementApi.get(entityId);
        if (a?.scope === "COURSE" && a.courseId) return `/courses/${a.courseId}`;
      } catch {
        // fall through to role home
      }
      return roleHome(role);
    }
    case "ASSIGNMENT": {
      // Assignment notifications carry the assignment id; open its course page.
      try {
        const a = await AssignmentApi.get(entityId);
        if (a?.courseId) return `/courses/${a.courseId}`;
      } catch {
        // fall through to no navigation
      }
      return null;
    }
    default:
      return null;
  }
}

export default function NotificationBell() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [items, setItems] = useState([]);
  const [open, setOpen] = useState(false);
  const boxRef = useRef(null);

  async function load() {
    try {
      const data = await NotificationApi.list();
      setItems(data);
    } catch {
      // ignore transient failures
    }
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 20000);
    const unsub = user ? subscribeToUserNotifications(user.id, () => load()) : () => {};
    function onClickOutside(e) {
      if (boxRef.current && !boxRef.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener("mousedown", onClickOutside);
    return () => {
      clearInterval(interval);
      unsub();
      document.removeEventListener("mousedown", onClickOutside);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  const unreadCount = items.filter((n) => !n.read).length;

  async function markRead(id) {
    await NotificationApi.markRead(id);
    load();
  }

  async function handleItemClick(n) {
    if (!n.read) await markRead(n.id);
    const route = await resolveRoute(n, user?.role);
    if (route) {
      setOpen(false);
      navigate(route);
    }
  }

  return (
    <div className="notif-bell" ref={boxRef}>
      <button className="btn btn-icon" onClick={() => setOpen((o) => !o)} aria-label="Notifications">
        🔔
        {unreadCount > 0 && <span className="notif-badge">{unreadCount}</span>}
      </button>
      {open && (
        <div className="notif-dropdown">
          <div className="notif-dropdown-header">Notifications</div>
          {items.length === 0 && <div className="notif-empty">You're all caught up.</div>}
          {items.map((n) => (
            <div key={n.id} className={`notif-item ${n.read ? "" : "unread"}`} onClick={() => handleItemClick(n)}>
              <div className="notif-msg">{n.message}</div>
              <div className="notif-time">{fmtDateTime(n.createdAt)}</div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
