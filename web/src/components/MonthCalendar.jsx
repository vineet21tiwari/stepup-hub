import { useMemo, useState } from "react";
import { sameDay, toDateInputValue } from "../utils/date";

const WEEKDAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function startOfMonth(date) {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

// Builds a fixed 6-week (42-day) grid covering the given month, starting on the Sunday on/before
// the 1st — same shape as any standard month calendar (Google Calendar, Outlook, etc).
function buildGrid(monthDate) {
  const first = startOfMonth(monthDate);
  const gridStart = new Date(first);
  gridStart.setDate(gridStart.getDate() - first.getDay());
  return Array.from({ length: 42 }, (_, i) => {
    const d = new Date(gridStart);
    d.setDate(gridStart.getDate() + i);
    return d;
  });
}

// Month-grid calendar that highlights days containing at least one item (a class), used wherever
// classes should read as a calendar instead of a flat list. Distinct from DayCalendar (the hourly
// single-day view used for slot booking) — this one's job is showing *which days* have something,
// not laying out same-day items by time-of-day.
export default function MonthCalendar({ items, dateField = "scheduledStart", selectedDate, onSelectDate }) {
  const [viewedMonth, setViewedMonth] = useState(() => startOfMonth(selectedDate || new Date()));

  const grid = useMemo(() => buildGrid(viewedMonth), [viewedMonth]);

  const countByDay = useMemo(() => {
    const counts = new Map();
    items.forEach((item) => {
      const key = toDateInputValue(new Date(item[dateField]));
      counts.set(key, (counts.get(key) || 0) + 1);
    });
    return counts;
  }, [items, dateField]);

  function changeMonth(delta) {
    setViewedMonth((m) => new Date(m.getFullYear(), m.getMonth() + delta, 1));
  }

  const today = new Date();

  return (
    <div className="month-calendar">
      <div className="month-calendar-nav">
        <button type="button" className="btn btn-ghost btn-sm" onClick={() => changeMonth(-1)}>
          ‹
        </button>
        <div className="month-calendar-label">
          {viewedMonth.toLocaleDateString(undefined, { month: "long", year: "numeric" })}
        </div>
        <button type="button" className="btn btn-ghost btn-sm" onClick={() => changeMonth(1)}>
          ›
        </button>
      </div>

      <div className="month-calendar-weekdays">
        {WEEKDAY_LABELS.map((d) => (
          <span key={d}>{d}</span>
        ))}
      </div>

      <div className="month-calendar-grid">
        {grid.map((day) => {
          const inMonth = day.getMonth() === viewedMonth.getMonth();
          const count = countByDay.get(toDateInputValue(day)) || 0;
          const isSelected = selectedDate && sameDay(day, selectedDate);
          const isToday = sameDay(day, today);
          return (
            <button
              type="button"
              key={day.toISOString()}
              className={`month-calendar-day ${inMonth ? "" : "outside"} ${isSelected ? "selected" : ""} ${isToday ? "today" : ""} ${count > 0 ? "has-class" : ""}`}
              onClick={() => onSelectDate(day)}
            >
              <span className="month-calendar-day-num">{day.getDate()}</span>
              {count > 0 && <span className="month-calendar-dot" title={`${count} class${count === 1 ? "" : "es"}`} />}
            </button>
          );
        })}
      </div>
    </div>
  );
}
