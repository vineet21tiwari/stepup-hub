import { useEffect, useRef, useState } from "react";
import { ChatApi } from "../api/endpoints";
import { subscribeToCourseChat } from "../api/socket";
import { useAuth } from "../context/AuthContext";
import { fmtDateTime } from "../utils/format";

// One chat thread per course (spans every class in it) — see ChatApi / backend ChatService.
export default function ChatRoom({ courseId }) {
  const { user } = useAuth();
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const bottomRef = useRef(null);

  useEffect(() => {
    let cancelled = false;
    ChatApi.history(courseId).then((data) => {
      if (!cancelled) setMessages(data);
    });
    const unsub = subscribeToCourseChat(courseId, (msg) => {
      setMessages((prev) => (prev.some((m) => m.id === msg.id) ? prev : [...prev, msg]));
    });
    return () => {
      cancelled = true;
      unsub();
    };
  }, [courseId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  async function send(e) {
    e.preventDefault();
    if (!draft.trim()) return;
    setSending(true);
    try {
      const msg = await ChatApi.send(courseId, draft.trim());
      setMessages((prev) => (prev.some((m) => m.id === msg.id) ? prev : [...prev, msg]));
      setDraft("");
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="chat-room">
      <div className="chat-messages">
        {messages.length === 0 && <div className="chat-empty">No messages yet. Say hello to the course!</div>}
        {messages.map((m) => (
          <div key={m.id} className={`chat-bubble ${m.senderId === user.id ? "mine" : ""}`}>
            <div className="chat-bubble-meta">
              <strong>{m.senderName}</strong>
              <span className="pill role-pill small">{m.senderRole}</span>
              <span className="chat-time">{fmtDateTime(m.sentAt)}</span>
            </div>
            <div className="chat-bubble-text">{m.content}</div>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>
      <form className="chat-input-row" onSubmit={send}>
        <input
          type="text"
          placeholder="Message the course..."
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          disabled={sending}
        />
        <button className="btn btn-primary" type="submit" disabled={sending || !draft.trim()}>
          Send
        </button>
      </form>
    </div>
  );
}
