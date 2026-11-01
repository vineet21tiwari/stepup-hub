// The whole platform's "wall clock" is India Standard Time, regardless of which timezone a given
// browser/device happens to be set to (server-side already anchors to this — see backend
// AppTime.ZONE). Every display and input-conversion helper below pins to it explicitly instead of
// silently falling back to the browser's ambient timezone, which would otherwise make the same
// instant look "off" whenever the viewer's or teacher's device isn't actually set to IST.
const IST = "Asia/Kolkata";
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

export function fmtDateTime(iso) {
  if (!iso) return "-";
  const d = new Date(iso);
  return d.toLocaleString(undefined, {
    timeZone: IST,
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function fmtDate(iso) {
  if (!iso) return "-";
  return new Date(iso).toLocaleDateString(undefined, {
    timeZone: IST,
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

export function fmtTime(iso) {
  if (!iso) return "-";
  return new Date(iso).toLocaleTimeString(undefined, { timeZone: IST, hour: "2-digit", minute: "2-digit" });
}

export function fmtTimeRange(startIso, endIso) {
  if (!startIso || !endIso) return "-";
  const s = new Date(startIso);
  const e = new Date(endIso);
  const sameDay = s.toLocaleDateString(undefined, { timeZone: IST }) === e.toLocaleDateString(undefined, { timeZone: IST });
  const dateStr = s.toLocaleDateString(undefined, { timeZone: IST, weekday: "short", month: "short", day: "numeric" });
  const startStr = s.toLocaleTimeString(undefined, { timeZone: IST, hour: "2-digit", minute: "2-digit" });
  const endStr = e.toLocaleTimeString(undefined, { timeZone: IST, hour: "2-digit", minute: "2-digit" });
  return sameDay ? `${dateStr}, ${startStr} - ${endStr}` : `${dateStr} ${startStr} - ${fmtDateTime(endIso)}`;
}

// Converts a "datetime-local" input value (no timezone info) to an ISO instant, treating the
// value as IST wall-clock time explicitly — not whatever timezone the browser happens to report.
export function localInputToIso(value) {
  if (!value) return null;
  return new Date(`${value}:00+05:30`).toISOString();
}

// Reverse of localInputToIso — formats an ISO instant as a "datetime-local" input value in IST,
// via arithmetic (shift by the IST offset, then read back with UTC getters) so it's correct
// regardless of the browser's own timezone.
export function isoToLocalInput(iso) {
  if (!iso) return "";
  const d = new Date(new Date(iso).getTime() + IST_OFFSET_MS);
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}T${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}

export function initials(name) {
  return (name || "?")
    .trim()
    .split(/\s+/)
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

// Collapses a list of EnrollmentRequestDto into one row per batchId (a weekly-commitment booking
// creates one request per dated occurrence, all sharing a batchId) — deciding on any one of them
// approves/rejects the whole batch server-side, so the approval UI only needs to show one card.
export function groupEnrollmentRequests(requests) {
  const groups = new Map();
  requests.forEach((r) => {
    const key = r.batchId || `single-${r.id}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(r);
  });
  return Array.from(groups.values()).map((items) => {
    const sorted = items.slice().sort((a, b) => new Date(a.slotStart) - new Date(b.slotStart));
    return { representative: sorted[0], count: sorted.length, items: sorted };
  });
}

// Dashboards should never sit empty just because nothing's scheduled for the rest of today: prefer
// the next few upcoming classes, and if there genuinely are none, fall back to the most recent past
// ones so there's still something useful to look at. Used by every role's home page.
export function pickRecentOrUpcoming(sessions, { upcomingLimit = 5, recentLimit = 3 } = {}) {
  const now = Date.now();
  const scheduled = sessions.filter((s) => s.status === "SCHEDULED");
  const upcoming = scheduled
    .filter((s) => new Date(s.scheduledStart).getTime() >= now)
    .sort((a, b) => new Date(a.scheduledStart) - new Date(b.scheduledStart))
    .slice(0, upcomingLimit);
  if (upcoming.length > 0) return { items: upcoming, mode: "upcoming" };

  const recent = scheduled
    .filter((s) => new Date(s.scheduledStart).getTime() < now)
    .sort((a, b) => new Date(b.scheduledStart) - new Date(a.scheduledStart))
    .slice(0, recentLimit);
  return { items: recent, mode: "recent" };
}

export function statusColor(status) {
  const s = (status || "").toUpperCase();
  if (s.includes("APPROVED") || s === "CONFIRMED" || s === "SCHEDULED") return "ok";
  if (s.includes("REJECTED") || s === "CANCELLED") return "bad";
  if (s.includes("PENDING")) return "warn";
  return "";
}
