import { useEffect, useState } from "react";
import { UserApi } from "../../api/endpoints";
import DirectChat from "../../components/DirectChat";

// Private 1:1 messaging with admin (see DirectMessageService) — pick an admin on the left, chat
// (with optional file attachments) on the right.
export default function CoordinatorMessages() {
  const [admins, setAdmins] = useState([]);
  const [selected, setSelected] = useState(null);

  useEffect(() => {
    UserApi.byRole("ADMIN").then(setAdmins);
  }, []);

  return (
    <div className="page">
      <h1>Message admin</h1>
      <p className="page-subtitle">Private 1:1 chat — share files like PDFs and images too.</p>

      <div className="browse-grid">
        <div className="browse-col">
          <h3>Admins</h3>
          <div className="list-select">
            {admins.map((a) => (
              <button
                key={a.id}
                className={`list-select-item ${selected?.id === a.id ? "active" : ""}`}
                onClick={() => setSelected(a)}
              >
                <div className="list-select-title">{a.name}</div>
                <div className="list-select-sub">{a.email}</div>
              </button>
            ))}
            {admins.length === 0 && <p className="empty-state">No admin accounts found.</p>}
          </div>
        </div>

        <div className="browse-col direct-chat-col">
          {selected ? (
            <DirectChat key={selected.id} otherUserId={selected.id} otherUserName={selected.name} />
          ) : (
            <p className="empty-state">Select an admin to start chatting.</p>
          )}
        </div>
      </div>
    </div>
  );
}
