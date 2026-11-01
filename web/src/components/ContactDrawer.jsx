import { Link } from "react-router-dom";

// A closeable side window offering the two class formats, converging on sign-up,
// plus a quick way to see direct contact details if the admin has set them.
export default function ContactDrawer({ open, onClose, contact }) {
  if (!open) return null;
  const hasDirectContact = contact.contactEmail || contact.contactPhone;

  return (
    <div className="contact-drawer-backdrop" onClick={onClose}>
      <div className="contact-drawer" onClick={(e) => e.stopPropagation()}>
        <div className="contact-drawer-header">
          <h3>Get in touch</h3>
          <button className="floating-chat-close" onClick={onClose} aria-label="Close">
            ×
          </button>
        </div>
        <p className="landing-lead">Choose the class format that fits you best, and sign up to get started.</p>

        <div className="contact-drawer-options">
          <Link to="/signup" className="contact-drawer-option" onClick={onClose}>
            <div className="contact-drawer-option-title">👥 Group Classes</div>
            <p>Learn together in a small group setting, at a lower cost per session.</p>
            <span className="btn btn-primary btn-sm">Sign up</span>
          </Link>
          <Link to="/signup" className="contact-drawer-option" onClick={onClose}>
            <div className="contact-drawer-option-title">🧑‍🏫 1-on-1 Classes</div>
            <p>Personalized one-on-one sessions tailored to your pace and goals.</p>
            <span className="btn btn-primary btn-sm">Sign up</span>
          </Link>
        </div>

        {hasDirectContact && (
          <div className="contact-drawer-direct">
            <div className="contact-drawer-direct-label">Prefer to reach out directly?</div>
            {contact.contactEmail && <div>{contact.contactEmail}</div>}
            {contact.contactPhone && <div>{contact.contactPhone}</div>}
          </div>
        )}
      </div>
    </div>
  );
}
