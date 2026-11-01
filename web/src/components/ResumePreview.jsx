import { useState } from "react";
import { fileUrl } from "../utils/files";

// Toggleable inline PDF preview (via <iframe>) instead of forcing a download/new-tab navigation
// just to check a file — used for both teacher resumes and course curriculum brochures.
export default function ResumePreview({ url, label = "resume" }) {
  const [open, setOpen] = useState(false);

  if (!url) return <span className="teacher-media-empty">No {label} uploaded</span>;

  return (
    <div className="resume-preview">
      <div className="btn-group">
        <button type="button" className="btn btn-ghost btn-sm" onClick={() => setOpen((o) => !o)}>
          {open ? `Hide ${label}` : `View ${label}`}
        </button>
        <a href={fileUrl(url)} target="_blank" rel="noreferrer" className="btn btn-ghost btn-sm">
          Open in new tab
        </a>
      </div>
      {open && <iframe src={fileUrl(url)} title={`${label} preview`} className="resume-preview-frame" />}
    </div>
  );
}
