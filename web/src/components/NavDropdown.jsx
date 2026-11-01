import { useEffect, useRef, useState } from "react";
import { NavLink, useLocation } from "react-router-dom";

// A navbar item that groups several links under one clickable label — closes on outside click,
// same pattern as NotificationBell's dropdown (useRef + mousedown listener).
export default function NavDropdown({ label, items }) {
  const [open, setOpen] = useState(false);
  const boxRef = useRef(null);
  const location = useLocation();
  const isActive = items.some((c) => location.pathname === c.to || location.pathname.startsWith(`${c.to}/`));

  useEffect(() => {
    function onClickOutside(e) {
      if (boxRef.current && !boxRef.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, []);

  return (
    <div className="navbar-dropdown" ref={boxRef}>
      <button type="button" className={`navbar-dropdown-trigger ${isActive ? "active" : ""}`} onClick={() => setOpen((o) => !o)}>
        {label} <span className="navbar-dropdown-caret">▾</span>
      </button>
      {open && (
        <div className="navbar-dropdown-menu">
          {items.map((c) => (
            <NavLink key={c.to} to={c.to} className={({ isActive: active }) => (active ? "active" : "")} onClick={() => setOpen(false)}>
              {c.label}
            </NavLink>
          ))}
        </div>
      )}
    </div>
  );
}
