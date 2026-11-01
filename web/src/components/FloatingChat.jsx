import { useEffect, useMemo, useRef, useState } from "react";
import { useMatch } from "react-router-dom";
import { NotificationApi, SessionApi } from "../api/endpoints";
import { subscribeToUserNotifications } from "../api/socket";
import { useAuth } from "../context/AuthContext";
import ChatRoom from "./ChatRoom";

// A corner pop-up over the course-scoped chat (one thread per course, covering every class in it —
// no direct/global messaging exists in the backend): pick a course, then chat there. On a course page
// (or a class page, which belongs to one course) it goes straight into that course's chat; otherwise
// it lists every course the user has classes in.
export default function FloatingChat() {
  const { user } = useAuth();
  const [open, setOpen] = useState(false);
  const [sessions, setSessions] = useState([]);
  const [activeCourseId, setActiveCourseId] = useState(null);
  const [notifications, setNotifications] = useState([]);
  const boxRef = useRef(null);
  const courseMatch = useMatch("/courses/:id");
  const sessionMatch = useMatch("/sessions/:id");
  const scopeCourseId = courseMatch?.params.id;
  const scopeSessionId = sessionMatch?.params.id;

  async function loadNotifications() {
    try {
      setNotifications(await NotificationApi.list());
    } catch {
      // ignore transient failures
    }
  }

  useEffect(() => {
    if (!user) return undefined;
    loadNotifications();
    const interval = setInterval(loadNotifications, 20000);
    const unsub = subscribeToUserNotifications(user.id, loadNotifications);
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

  useEffect(() => {
    if (open && sessions.length === 0) {
      SessionApi.mine().then(setSessions);
    }
  }, [open, sessions.length]);

  // Going to another page starts from that page's own chat again.
  useEffect(() => {
    setActiveCourseId(null);
  }, [scopeCourseId, scopeSessionId]);

  const courses = useMemo(() => {
    const byId = new Map();
    sessions.forEach((s) => {
      if (!byId.has(s.courseId)) byId.set(s.courseId, { courseId: s.courseId, courseTitle: s.courseTitle });
    });
    return Array.from(byId.values()).sort((a, b) => a.courseTitle.localeCompare(b.courseTitle));
  }, [sessions]);

  if (!user) return null;

  // A page scoped to one course (or one class, which belongs to one course) goes straight into it.
  const scopedCourseId =
    scopeCourseId || (scopeSessionId && sessions.find((s) => String(s.id) === scopeSessionId)?.courseId);
  const current = activeCourseId || (scopedCourseId ? Number(scopedCourseId) : null);
  const canGoBack = activeCourseId && !scopedCourseId && courses.length > 1;
  const currentTitle = courses.find((c) => c.courseId === current)?.courseTitle;

  const unreadCourseIds = new Set(
    notifications
      .filter((n) => n.type === "NEW_CHAT_MESSAGE" && !n.read)
      .map((n) => Number((n.relatedEntity || "").split(":")[1]))
  );
  const unreadCount = unreadCourseIds.size;

  async function openCourse(courseId) {
    setActiveCourseId(courseId);
    const toMark = notifications.filter(
      (n) => n.type === "NEW_CHAT_MESSAGE" && !n.read && n.relatedEntity === `COURSE:${courseId}`
    );
    if (toMark.length > 0) {
      await Promise.all(toMark.map((n) => NotificationApi.markRead(n.id)));
      loadNotifications();
    }
  }

  return (
    <div className="floating-chat" ref={boxRef}>
      {open && (
        <div className="floating-chat-panel">
          <div className="floating-chat-header">
            {current ? (
              <>
                {canGoBack && (
                  <button className="floating-chat-back" onClick={() => setActiveCourseId(null)} aria-label="Back to courses">
                    ‹
                  </button>
                )}
                <span>{currentTitle}</span>
              </>
            ) : (
              <span>Course chat</span>
            )}
            <button className="floating-chat-close" onClick={() => setOpen(false)} aria-label="Close chat">
              ×
            </button>
          </div>
          {current ? (
            <ChatRoom key={current} courseId={current} />
          ) : (
            <div className="floating-chat-list">
              {courses.length === 0 && <p className="empty-state">No courses to chat in yet.</p>}
              {courses.map((c) => (
                <button key={c.courseId} className="floating-chat-session" onClick={() => openCourse(c.courseId)}>
                  <div className="floating-chat-session-title">
                    {c.courseTitle}
                    {unreadCourseIds.has(c.courseId) && <span className="floating-chat-dot" />}
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>
      )}
      <button className="floating-chat-bubble" onClick={() => setOpen((o) => !o)} aria-label="Toggle chat">
        💬
        {unreadCount > 0 && <span className="notif-badge">{unreadCount}</span>}
      </button>
    </div>
  );
}
