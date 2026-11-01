import { useEffect, useRef, useState } from "react";
import { TaskApi } from "../api/endpoints";
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

// A task's file-sharing message thread — same look as DirectChat/ChatRoom, but polls (tasks have no
// dedicated realtime topic, unlike course chat / admin-coordinator DMs) since task threads are far
// lower-traffic and usually opened alongside checking task status rather than kept open continuously.
export default function TaskThread({ taskId }) {
  const { user } = useAuth();
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState("");
  const [file, setFile] = useState(null);
  const [fileKey, setFileKey] = useState(0);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const bottomRef = useRef(null);

  async function load() {
    setMessages(await TaskApi.messages(taskId));
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 8000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [taskId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  async function send(e) {
    e.preventDefault();
    if (!draft.trim() && !file) return;
    setSending(true);
    setError("");
    try {
      const msg = await TaskApi.sendMessage(taskId, draft.trim(), file);
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
        {messages.length === 0 && <div className="chat-empty">No messages on this task yet.</div>}
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
