import { useEffect, useState } from "react";
import { AnnouncementApi } from "../api/endpoints";
import { subscribeToUserNotifications } from "../api/socket";
import { useAuth } from "../context/AuthContext";

const DISMISSED_KEY = "stepup_dismissed_announcements";

function loadDismissed() {
  try {
    return JSON.parse(localStorage.getItem(DISMISSED_KEY)) || [];
  } catch {
    return [];
  }
}

export default function GlobalAnnouncements() {
  const { user } = useAuth();
  const [announcements, setAnnouncements] = useState([]);
  const [dismissed, setDismissed] = useState(loadDismissed);

  useEffect(() => {
    function load() {
      AnnouncementApi.global().then(setAnnouncements).catch(() => {});
    }
    load();
    const unsub = user ? subscribeToUserNotifications(user.id, load) : () => {};
    return unsub;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  function dismiss(id) {
    const next = [...dismissed, id];
    setDismissed(next);
    localStorage.setItem(DISMISSED_KEY, JSON.stringify(next));
  }

  const visible = announcements.filter((a) => !dismissed.includes(a.id)).slice(0, 3);
  if (visible.length === 0) return null;

  return (
    <div className="announcement-strip">
      {visible.map((a) => (
        <div className="announcement-banner" key={a.id}>
          <div>
            <span className="announcement-title">{a.title}</span>
            <span className="announcement-message">{a.message}</span>
          </div>
          <button className="announcement-dismiss" onClick={() => dismiss(a.id)} aria-label="Dismiss announcement">
            ×
          </button>
        </div>
      ))}
    </div>
  );
}
