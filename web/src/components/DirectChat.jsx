import { useEffect, useRef, useState } from "react";
import { DirectMessageApi } from "../api/endpoints";
import { subscribeToDirectMessages } from "../api/socket";
import { useAuth } from "../context/AuthContext";
import { fileUrl } from "../utils/files";
import { fmtDateTime } from "../utils/format";

const IMAGE_EXT = /\.(png|jpe?g|gif|webp)$/i;

function Attachment({ url, name }) {
  if (!url) return null;
  const href = fileUrl(url);
  if (IMAGE_EXT.test(url)) {
    return (
      <a href={href} target="_blank" rel="noreferrer">
        <img src={href} alt={name || "attachment"} className="chat-attachment-image" />
      </a>
    );
  }
  return (
    <a href={href} target="_blank" rel="noreferrer" className="chat-attachment-file">
      📎 {name || "Download attachment"}
    </a>
  );
}

// Private 1:1 thread between the current user and `otherUserId` (Admin<->Coordinator only — see
// backend DirectMessageService). Adds an optional file attachment (image/PDF) alongside text,
// unlike the course chat this is adapted from (ChatRoom.jsx).
export default function DirectChat({ otherUserId, otherUserName }) {
  const { user } = useAuth();
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState("");
  const [file, setFile] = useState(null);
  const [fileKey, setFileKey] = useState(0);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const bottomRef = useRef(null);

  useEffect(() => {
    let cancelled = false;
    setMessages([]);
    DirectMessageApi.history(otherUserId).then((data) => {
      if (!cancelled) setMessages(data);
    });
    const unsub = subscribeToDirectMessages(user.id, otherUserId, (msg) => {
      setMessages((prev) => (prev.some((m) => m.id === msg.id) ? prev : [...prev, msg]));
    });
    return () => {
      cancelled = true;
      unsub();
    };
  }, [otherUserId, user.id]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  async function send(e) {
    e.preventDefault();
    if (!draft.trim() && !file) return;
    setSending(true);
    setError("");
    try {
      const msg = await DirectMessageApi.send(otherUserId, draft.trim(), file);
      setMessages((prev) => (prev.some((m) => m.id === msg.id) ? prev : [...prev, msg]));
      setDraft("");
      setFile(null);
      setFileKey((k) => k + 1);
    } catch (err) {
      setError(err.message);
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="chat-room">
      <div className="chat-messages">
        {messages.length === 0 && <div className="chat-empty">No messages yet with {otherUserName}.</div>}
        {messages.map((m) => (
          <div key={m.id} className={`chat-bubble ${m.senderId === user.id ? "mine" : ""}`}>
            <div className="chat-bubble-meta">
              <strong>{m.senderName}</strong>
              <span className="chat-time">{fmtDateTime(m.sentAt)}</span>
            </div>
            {m.content && <div className="chat-bubble-text">{m.content}</div>}
            <Attachment url={m.attachmentUrl} name={m.attachmentName} />
          </div>
        ))}
        <div ref={bottomRef} />
      </div>
      {error && <div className="banner banner-error">{error}</div>}
      <form className="chat-input-row" onSubmit={send}>
        <input type="text" placeholder="Message..." value={draft} onChange={(e) => setDraft(e.target.value)} disabled={sending} />
        <input
          key={fileKey}
          type="file"
          accept="image/*,.pdf"
          className="chat-file-input"
          onChange={(e) => setFile(e.target.files?.[0] || null)}
          disabled={sending}
        />
        <button className="btn btn-primary" type="submit" disabled={sending || (!draft.trim() && !file)}>
          Send
        </button>
      </form>
    </div>
  );
}
