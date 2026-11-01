import { useEffect, useState } from "react";
import { UserApi } from "../../api/endpoints";
import DirectChat from "../../components/DirectChat";

// Private 1:1 messaging with each coordinator (see DirectMessageService) — pick a coordinator on the
// left, chat (with optional file attachments) on the right.
export default function AdminCoordinatorChat() {
  const [coordinators, setCoordinators] = useState([]);
  const [selected, setSelected] = useState(null);

  useEffect(() => {
    UserApi.byRole("COORDINATOR").then(setCoordinators);
  }, []);

  return (
    <div className="page">
      <h1>Message coordinators</h1>
      <p className="page-subtitle">Private 1:1 chat with each coordinator — share files like PDFs and images too.</p>

      <div className="browse-grid">
        <div className="browse-col">
          <h3>Coordinators</h3>
          <div className="list-select">
            {coordinators.map((c) => (
              <button
                key={c.id}
                className={`list-select-item ${selected?.id === c.id ? "active" : ""}`}
                onClick={() => setSelected(c)}
              >
                <div className="list-select-title">{c.name}</div>
                <div className="list-select-sub">{c.email}</div>
              </button>
            ))}
            {coordinators.length === 0 && <p className="empty-state">No coordinator accounts yet.</p>}
          </div>
        </div>

        <div className="browse-col direct-chat-col">
          {selected ? (
            <DirectChat key={selected.id} otherUserId={selected.id} otherUserName={selected.name} />
          ) : (
            <p className="empty-state">Select a coordinator to start chatting.</p>
          )}
        </div>
      </div>
    </div>
  );
}
