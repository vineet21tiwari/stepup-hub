import { useEffect, useMemo, useRef } from "react";
import { addDays, minutesSinceMidnightIst, sameDay } from "../utils/date";

const HOUR_HEIGHT = 56; // px per hour row
const DAY_HEIGHT = HOUR_HEIGHT * 24;
const IST = "Asia/Kolkata";

function hourLabel(h) {
  if (h === 0) return "12 AM";
  if (h === 12) return "12 PM";
  return h < 12 ? `${h} AM` : `${h - 12} PM`;
}

// Google-Calendar-style single-day view: 24 hourly rows, a "now" line when viewing today,
// and items positioned as absolute blocks by time-of-day. `renderItem` returns the clickable
// content for one item (e.g. a bookable slot chip) — this component only handles layout.
export default function DayCalendar({
  date,
  onDateChange,
  items,
  dateField = "startTime",
  endField = "endTime",
  blockedRanges = [],
  renderItem,
  emptyText,
  dayDisabled = false,
  dayDisabledReason,
}) {
  const scrollRef = useRef(null);
  const isToday = sameDay(date, new Date());

  const dayItems = useMemo(
    () =>
      items
        .filter((i) => sameDay(new Date(i[dateField]), date))
        .sort((a, b) => new Date(a[dateField]) - new Date(b[dateField])),
    [items, dateField, date]
  );

  useEffect(() => {
    if (!scrollRef.current) return;
    // Prefer scrolling straight to this day's earliest slot — falling back to "now" (today) or
    // 8am (other days) only when the day has nothing to show — so a slot never sits scrolled out
    // of view below an empty-looking fold.
    const earliestItemMinutes = dayItems.length ? minutesSinceMidnightIst(new Date(dayItems[0][dateField])) : null;
    const anchorMinutes = earliestItemMinutes ?? (isToday ? minutesSinceMidnightIst(new Date()) : 8 * 60);
    const top = Math.max(0, (anchorMinutes / 60) * HOUR_HEIGHT - HOUR_HEIGHT * 2);
    scrollRef.current.scrollTop = top;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [date, dayItems]);

  const nowTop = isToday ? (minutesSinceMidnightIst(new Date()) / 60) * HOUR_HEIGHT : null;

  function blockStyle(startIso, endIso) {
    const s = new Date(startIso);
    const e = new Date(endIso);
    const top = (minutesSinceMidnightIst(s) / 60) * HOUR_HEIGHT;
    const rawHeight = ((e - s) / 60000 / 60) * HOUR_HEIGHT;
    // Inset by 2px top/bottom so back-to-back hourly slots show a visible gap instead of
    // touching edge-to-edge like one solid, undifferentiated block.
    return { top: top + 2, height: Math.max(20, rawHeight - 4) };
  }

  return (
    <div className="day-calendar">
      <div className="day-calendar-nav">
        <button type="button" className="btn btn-ghost btn-sm" onClick={() => onDateChange(addDays(date, -1))}>
          ‹ Prev day
        </button>
        <div className="day-calendar-label">
          {date.toLocaleDateString(undefined, { timeZone: IST, weekday: "long", month: "short", day: "numeric" })}
          {isToday && <span className="pill small">Today</span>}
        </div>
        <button type="button" className="btn btn-ghost btn-sm" onClick={() => onDateChange(addDays(date, 1))}>
          Next day ›
        </button>
      </div>

      {dayDisabled && dayDisabledReason && <div className="banner banner-warn">{dayDisabledReason}</div>}

      <div className="day-calendar-scroll" ref={scrollRef}>
        <div className="day-calendar-grid" style={{ height: DAY_HEIGHT }}>
          {Array.from({ length: 24 }, (_, h) => (
            <div className="day-calendar-hour-row" key={h} style={{ top: h * HOUR_HEIGHT, height: HOUR_HEIGHT }}>
              <span className="day-calendar-hour-label">{hourLabel(h)}</span>
            </div>
          ))}

          {nowTop != null && (
            <div className="day-calendar-now-line" style={{ top: nowTop }}>
              <span className="day-calendar-now-dot" />
            </div>
          )}

          {blockedRanges.map((r, idx) => (
            <div className="day-calendar-blocked" key={`blocked-${idx}`} style={blockStyle(r.start, r.end)}>
              Teacher unavailable
            </div>
          ))}

          {!dayDisabled &&
            dayItems.map((item) => (
              <div className="day-calendar-event" key={item.id} style={blockStyle(item[dateField], item[endField])}>
                {renderItem(item)}
              </div>
            ))}
        </div>
      </div>

      {!dayDisabled && dayItems.length === 0 && <p className="empty-state day-calendar-empty">{emptyText || "No slots this day"}</p>}
    </div>
  );
}
