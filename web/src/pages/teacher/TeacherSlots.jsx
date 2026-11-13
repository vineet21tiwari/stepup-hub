import { useEffect, useMemo, useRef, useState } from "react";
import { TeacherApi } from "../../api/endpoints";
import { fmtDate, fmtTime, fmtTimeRange, isoToLocalInput, localInputToIso } from "../../utils/format";
import WeekdayPicker from "../../components/WeekdayPicker";
import DayCalendar from "../../components/DayCalendar";

// Maps JS Date.getDay() (0=Sunday..6=Saturday) to java.time.DayOfWeek enum names.
const JS_DAY_TO_JAVA_DAY = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
const DAY_LABEL = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// "Today" in IST specifically (not the browser's own timezone), matching how the weekly-plan
// dates are interpreted server-side.
function todayInputValue() {
  return new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" });
}

const newRange = () => ({ start: "", end: "" });

export default function TeacherSlots() {
  const [approvedCourses, setApprovedCourses] = useState([]);
  const [slots, setSlots] = useState([]);
  const [mode, setMode] = useState("weekly");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [viewedDate, setViewedDate] = useState(new Date());
  const calendarInitialized = useRef(false);

  const [singleForm, setSingleForm] = useState({ courseId: "", startTime: "", endTime: "", capacity: 1 });

  const [weeklyForm, setWeeklyForm] = useState({
    courseId: "",
    sessionType: "ONE_ON_ONE",
    capacity: 1,
    classesPerWeek: 1,
    weekdays: [],
    dayTimes: {}, // { [jsDay]: [{start, end}, ...] }
    startDate: todayInputValue(),
    endDate: "",
  });

  const [expandedSeries, setExpandedSeries] = useState(null);
  const [editing, setEditing] = useState(null); // { id, startTime, endTime, capacity }

  async function load() {
    const [apps, mySlots] = await Promise.all([TeacherApi.myApplications(), TeacherApi.mySlots()]);
    setApprovedCourses(apps.filter((a) => a.status === "APPROVED"));
    setSlots(mySlots);
    if (!calendarInitialized.current) {
      const now = new Date();
      const upcoming = mySlots.map((s) => new Date(s.startTime)).filter((d) => d >= now);
      if (upcoming.length) {
        setViewedDate(upcoming.sort((a, b) => a - b)[0]);
        calendarInitialized.current = true;
      }
    }
  }

  useEffect(() => {
    load();
  }, []);

  function updateWeekly(field, value) {
    setWeeklyForm((f) => ({ ...f, [field]: value }));
  }

  function toggleWeekday(days) {
    setWeeklyForm((f) => {
      const dayTimes = {};
      days.forEach((d) => {
        dayTimes[d] = f.dayTimes[d] && f.dayTimes[d].length ? f.dayTimes[d] : [newRange()];
      });
      const nextClassesPerWeek = Math.min(Number(f.classesPerWeek) || 1, days.length) || (days.length ? 1 : 0);
      return { ...f, weekdays: days, dayTimes, classesPerWeek: nextClassesPerWeek };
    });
  }

  function setRange(day, idx, field, value) {
    setWeeklyForm((f) => {
      const ranges = (f.dayTimes[day] || []).map((r, i) => (i === idx ? { ...r, [field]: value } : r));
      return { ...f, dayTimes: { ...f.dayTimes, [day]: ranges } };
    });
  }

  function addRange(day) {
    setWeeklyForm((f) => ({ ...f, dayTimes: { ...f.dayTimes, [day]: [...(f.dayTimes[day] || []), newRange()] } }));
  }

  function removeRange(day, idx) {
    setWeeklyForm((f) => {
      const ranges = (f.dayTimes[day] || []).filter((_, i) => i !== idx);
      return { ...f, dayTimes: { ...f.dayTimes, [day]: ranges.length ? ranges : [newRange()] } };
    });
  }

  function copyDayTo(day, targets) {
    setWeeklyForm((f) => {
      const src = (f.dayTimes[day] || []).map((r) => ({ ...r }));
      const dayTimes = { ...f.dayTimes };
      targets.forEach((t) => {
        if (t !== day) dayTimes[t] = src.map((r) => ({ ...r }));
      });
      return { ...f, dayTimes };
    });
  }

  function validRanges(ranges) {
    return ranges.every((r) => r.start && r.end);
  }

  async function createSingleSlot(e) {
    e.preventDefault();
    setError("");
    setNotice("");
    setBusy(true);
    try {
      await TeacherApi.createSlot({
        courseId: Number(singleForm.courseId),
        startTime: localInputToIso(singleForm.startTime),
        endTime: localInputToIso(singleForm.endTime),
        capacity: Number(singleForm.capacity) || 1,
      });
      setNotice("Slot added.");
      setSingleForm((f) => ({ ...f, startTime: "", endTime: "" }));
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function createWeeklyAvailability(e) {
    e.preventDefault();
    setError("");
    setNotice("");
    if (weeklyForm.weekdays.length === 0) return setError("Pick at least one day of the week.");
    for (const day of weeklyForm.weekdays) {
      const ranges = weeklyForm.dayTimes[day] || [];
      if (!ranges.length || !validRanges(ranges)) return setError(`Set a start and end time for every slot on ${DAY_LABEL[day]}.`);
      for (const r of ranges) {
        if (r.end <= r.start) return setError(`End time must be after start time on ${DAY_LABEL[day]}.`);
      }
      const sorted = ranges.slice().sort((a, b) => a.start.localeCompare(b.start));
      for (let i = 1; i < sorted.length; i++) {
        if (sorted[i].start < sorted[i - 1].end) return setError(`Time slots overlap on ${DAY_LABEL[day]}.`);
      }
    }
    if (!weeklyForm.endDate) return setError("Pick a repeat-until date.");
    if (weeklyForm.endDate < weeklyForm.startDate) return setError("Repeat-until date must be on or after the start date.");
    const classesPerWeek = Number(weeklyForm.classesPerWeek);
    if (!classesPerWeek || classesPerWeek < 1 || classesPerWeek > weeklyForm.weekdays.length) {
      return setError(`Classes per week must be between 1 and ${weeklyForm.weekdays.length} (the number of days you offered).`);
    }

    setBusy(true);
    try {
      const created = await TeacherApi.createRecurringSlots({
        courseId: Number(weeklyForm.courseId),
        sessionType: weeklyForm.sessionType,
        capacity: weeklyForm.sessionType === "ONE_ON_ONE" ? 1 : Number(weeklyForm.capacity) || 1,
        classesPerWeek,
        startDate: weeklyForm.startDate,
        repeatUntil: weeklyForm.endDate,
        dayWindows: weeklyForm.weekdays.flatMap((d) =>
          weeklyForm.dayTimes[d].map((r) => ({ dayOfWeek: JS_DAY_TO_JAVA_DAY[d], startTime: r.start, endTime: r.end }))
        ),
      });
      setNotice(`Created ${created.length} slot${created.length === 1 ? "" : "s"}.`);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function removeSlot(s) {
    if (!confirm(`Remove the slot on ${fmtTimeRange(s.startTime, s.endTime)}?`)) return;
    setError("");
    try {
      await TeacherApi.cancelSlot(s.id);
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function removeEmptyInSeries(group) {
    if (!confirm("Remove every EMPTY slot in this series? Slots booked or requested by students will stay.")) return;
    setError("");
    setNotice("");
    try {
      const res = await TeacherApi.cancelSlotSeries(group.id);
      setNotice(`Removed ${res.cancelled} empty slot(s).${res.keptBooked ? ` ${res.keptBooked} booked slot(s) kept — only admin can cancel those.` : ""}`);
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function saveEdit(e) {
    e.preventDefault();
    setError("");
    try {
      await TeacherApi.updateSlot(editing.id, {
        courseId: editing.courseId,
        startTime: localInputToIso(editing.startTime),
        endTime: localInputToIso(editing.endTime),
        capacity: Number(editing.capacity) || 1,
      });
      setEditing(null);
      setNotice("Slot updated. Students with a pending request were notified of the new time.");
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  // Slots grouped by series (one-off slots each form their own group), upcoming first.
  const groups = useMemo(() => {
    const map = new Map();
    slots.forEach((s) => {
      const key = s.recurrenceGroupId || `single-${s.id}`;
      if (!map.has(key)) map.set(key, { id: s.recurrenceGroupId, key, series: !!s.recurrenceGroupId, slots: [] });
      map.get(key).slots.push(s);
    });
    return Array.from(map.values())
      .map((g) => {
        g.slots.sort((a, b) => new Date(a.startTime) - new Date(b.startTime));
        g.first = g.slots[0];
        g.booked = g.slots.filter((s) => s.bookedCount > 0).length;
        return g;
      })
      .sort((a, b) => new Date(a.first.startTime) - new Date(b.first.startTime));
  }, [slots]);

  function renderSlotRow(s) {
    const locked = s.bookedCount > 0;
    if (editing?.id === s.id) {
      return (
        <form className="slot-edit-row" key={s.id} onSubmit={saveEdit}>
          <input type="datetime-local" required value={editing.startTime} onChange={(e) => setEditing((x) => ({ ...x, startTime: e.target.value }))} />
          <input type="datetime-local" required value={editing.endTime} onChange={(e) => setEditing((x) => ({ ...x, endTime: e.target.value }))} />
          <div className="btn-group">
            <button className="btn btn-primary btn-sm" type="submit">Save</button>
            <button className="btn btn-ghost btn-sm" type="button" onClick={() => setEditing(null)}>Cancel</button>
          </div>
        </form>
      );
    }
    return (
      <div className={`slot-row ${locked ? "locked" : ""}`} key={s.id}>
        <div className="slot-row-main">
          <span className="slot-row-time">{fmtTimeRange(s.startTime, s.endTime)}</span>
          <span className="slot-row-cap">
            {s.bookedCount}/{s.capacity} booked
          </span>
        </div>
        {locked ? (
          <span className="pill small status-ok" title="Booked by a student — can't be changed. Raise a change request from the class, or ask admin.">
            Booked
          </span>
        ) : (
          <div className="btn-group">
            <button
              className="btn btn-ghost btn-sm"
              onClick={() =>
                setEditing({
                  id: s.id,
                  courseId: s.courseId,
                  startTime: isoToLocalInput(s.startTime),
                  endTime: isoToLocalInput(s.endTime),
                  capacity: s.capacity,
                })
              }
            >
              Edit
            </button>
            <button className="btn btn-ghost btn-sm btn-danger-ghost" onClick={() => removeSlot(s)}>
              Remove
            </button>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="page">
      <h1>My slots</h1>
      <p className="page-subtitle">Set your weekly availability, or add a one-off slot, for courses you're approved to teach.</p>

      {error && <div className="banner banner-error">{error}</div>}
      {notice && <div className="banner banner-info">{notice}</div>}

      {approvedCourses.length === 0 ? (
        <p className="empty-state">You don't have any approved courses yet. Apply to a course and wait for Admin approval.</p>
      ) : (
        <div className="card form-card">
          <div className="segmented slot-mode-toggle">
            <button type="button" className={`segmented-btn ${mode === "weekly" ? "active" : ""}`} onClick={() => setMode("weekly")}>
              Weekly availability
            </button>
            <button type="button" className={`segmented-btn ${mode === "single" ? "active" : ""}`} onClick={() => setMode("single")}>
              Single slot
            </button>
          </div>

          {mode === "weekly" && (
            <form onSubmit={createWeeklyAvailability}>
              <div className="form-row">
                <div>
                  <label>Course</label>
                  <select required value={weeklyForm.courseId} onChange={(e) => updateWeekly("courseId", e.target.value)}>
                    <option value="">Select course</option>
                    {approvedCourses.map((a) => (
                      <option key={a.courseId} value={a.courseId}>
                        {a.courseTitle}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label>Session type</label>
                  <div className="segmented">
                    <button
                      type="button"
                      className={`segmented-btn ${weeklyForm.sessionType === "ONE_ON_ONE" ? "active" : ""}`}
                      onClick={() => updateWeekly("sessionType", "ONE_ON_ONE")}
                    >
                      1-on-1
                    </button>
                    <button
                      type="button"
                      className={`segmented-btn ${weeklyForm.sessionType === "GROUP" ? "active" : ""}`}
                      onClick={() => updateWeekly("sessionType", "GROUP")}
                    >
                      Group
                    </button>
                  </div>
                </div>
              </div>

              <div className="form-row">
                <div>
                  <label>Classes per week needed</label>
                  <input
                    type="number"
                    min="1"
                    max={weeklyForm.weekdays.length || 1}
                    value={weeklyForm.classesPerWeek}
                    onChange={(e) => updateWeekly("classesPerWeek", e.target.value)}
                  />
                </div>
                {weeklyForm.sessionType === "GROUP" && (
                  <div>
                    <label>Capacity per class</label>
                    <input type="number" min="1" value={weeklyForm.capacity} onChange={(e) => updateWeekly("capacity", e.target.value)} />
                  </div>
                )}
              </div>

              <label>Which days are you free for this course?</label>
              <WeekdayPicker selected={weeklyForm.weekdays} onChange={toggleWeekday} />

              {weeklyForm.weekdays.length > 0 && (
                <div className="day-window-list">
                  {weeklyForm.weekdays.map((day, idx) => {
                    const ranges = weeklyForm.dayTimes[day] || [newRange()];
                    const prevDay = idx > 0 ? weeklyForm.weekdays[idx - 1] : null;
                    const prevOk = prevDay != null && validRanges(weeklyForm.dayTimes[prevDay] || []);
                    const thisOk = validRanges(ranges);
                    return (
                      <div className="day-window-card" key={day}>
                        <div className="day-window-head">
                          <span className="day-window-label">{DAY_LABEL[day]}</span>
                          <div className="btn-group btn-group-wrap">
                            {prevDay != null && (
                              <button
                                type="button"
                                className="btn btn-ghost btn-xs"
                                disabled={!prevOk}
                                title={prevOk ? `Copy ${DAY_LABEL[prevDay]}'s slots` : `Set ${DAY_LABEL[prevDay]}'s times first`}
                                onClick={() => copyDayTo(prevDay, [day])}
                              >
                                Same as {DAY_LABEL[prevDay]}
                              </button>
                            )}
                            {weeklyForm.weekdays.length > 1 && (
                              <button
                                type="button"
                                className="btn btn-ghost btn-xs"
                                disabled={!thisOk}
                                title={thisOk ? `Copy ${DAY_LABEL[day]}'s slots to every selected day` : "Set the times first"}
                                onClick={() => copyDayTo(day, weeklyForm.weekdays)}
                              >
                                Copy to all days
                              </button>
                            )}
                          </div>
                        </div>
                        {ranges.map((r, i) => (
                          <div className="day-window-row" key={i}>
                            <input type="time" required value={r.start} onChange={(e) => setRange(day, i, "start", e.target.value)} aria-label="From" />
                            <span className="day-window-to">to</span>
                            <input type="time" required value={r.end} onChange={(e) => setRange(day, i, "end", e.target.value)} aria-label="To" />
                            {ranges.length > 1 ? (
                              <button type="button" className="icon-btn" title="Remove this time slot" onClick={() => removeRange(day, i)}>
                                ×
                              </button>
                            ) : (
                              <span className="icon-btn-spacer" />
                            )}
                          </div>
                        ))}
                        <button type="button" className="add-range-btn" onClick={() => addRange(day)}>
                          <span className="add-range-plus">+</span> Add another time slot
                        </button>
                      </div>
                    );
                  })}
                </div>
              )}

              <div className="form-row">
                <div>
                  <label>Repeat from</label>
                  <input type="date" required min={todayInputValue()} value={weeklyForm.startDate} onChange={(e) => updateWeekly("startDate", e.target.value)} />
                </div>
                <div>
                  <label>Repeat until</label>
                  <input type="date" required value={weeklyForm.endDate} onChange={(e) => updateWeekly("endDate", e.target.value)} />
                </div>
              </div>

              <p className="form-hint">
                Each time range is split into 1-hour slots on every matching day. Students will pick{" "}
                {weeklyForm.classesPerWeek || "N"} of your offered day{weeklyForm.weekdays.length === 1 ? "" : "s"} per week. Once a
                student books a slot, you can't change or remove it.
              </p>

              <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
                {busy ? "Creating slots..." : "Create weekly availability"}
              </button>
            </form>
          )}

          {mode === "single" && (
            <form onSubmit={createSingleSlot}>
              <div className="form-row">
                <div>
                  <label>Course</label>
                  <select required value={singleForm.courseId} onChange={(e) => setSingleForm((f) => ({ ...f, courseId: e.target.value }))}>
                    <option value="">Select course</option>
                    {approvedCourses.map((a) => (
                      <option key={a.courseId} value={a.courseId}>
                        {a.courseTitle}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label>Capacity</label>
                  <input type="number" min="1" value={singleForm.capacity} onChange={(e) => setSingleForm((f) => ({ ...f, capacity: e.target.value }))} />
                </div>
              </div>
              <div className="form-row">
                <div>
                  <label>Start time</label>
                  <input type="datetime-local" required value={singleForm.startTime} onChange={(e) => setSingleForm((f) => ({ ...f, startTime: e.target.value }))} />
                </div>
                <div>
                  <label>End time</label>
                  <input type="datetime-local" required value={singleForm.endTime} onChange={(e) => setSingleForm((f) => ({ ...f, endTime: e.target.value }))} />
                </div>
              </div>
              <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
                {busy ? "Adding..." : "Add slot"}
              </button>
            </form>
          )}
        </div>
      )}

      <div className="section">
        <h2>Your schedule</h2>
        {slots.length === 0 ? (
          <p className="empty-state">No slots posted yet.</p>
        ) : (
          <DayCalendar
            date={viewedDate}
            onDateChange={setViewedDate}
            items={slots}
            dateField="startTime"
            endField="endTime"
            emptyText="No slots this day"
            renderItem={(s) => (
              <div className={`week-slot-chip teacher-slot-chip ${s.full ? "full" : ""}`}>
                <span className="week-slot-time">{s.courseTitle}</span>
                <span className="week-slot-cap">
                  {fmtTime(s.startTime)}–{fmtTime(s.endTime)} · {s.bookedCount}/{s.capacity}
                </span>
              </div>
            )}
          />
        )}
      </div>

      <div className="section">
        <h2>Manage slots</h2>
        <p className="form-hint">Booked slots are locked. To move a booked class, open it and raise a change request; only admin can cancel booked slots.</p>
        <div className="card-list">
          {groups.map((g) => {
            const open = expandedSeries === g.key || !g.series;
            return (
              <div className="card" key={g.key}>
                <div className="card-row card-row-stack">
                  <div className="card-row-main">
                    <div className="card-title">
                      {g.first.courseTitle}
                      <span className="pill small">{g.series ? "Weekly series" : "One-off"}</span>
                      <span className="pill small">{g.first.sessionType === "GROUP" ? "Group" : "1-on-1"}</span>
                    </div>
                    {g.series && (
                      <div className="card-sub">
                        {fmtDate(g.first.startTime)} → {fmtDate(g.slots[g.slots.length - 1].startTime)}
                      </div>
                    )}
                    <div className="card-sub">
                      {g.slots.length} slot{g.slots.length === 1 ? "" : "s"} · {g.booked} booked
                      {g.first.classesPerWeek > 0 ? ` · ${g.first.classesPerWeek} classes/week` : ""}
                    </div>
                  </div>
                  {g.series && (
                    <div className="card-actions">
                      <button className="btn btn-ghost btn-sm" onClick={() => setExpandedSeries(open ? null : g.key)}>
                        {open ? "Hide slots" : "View slots"}
                      </button>
                      <button className="btn btn-ghost btn-sm btn-danger-ghost" onClick={() => removeEmptyInSeries(g)}>
                        Remove empty slots
                      </button>
                    </div>
                  )}
                </div>
                {open && (
                  <div className="slot-rows">
                    {g.slots.map((s) => renderSlotRow(s))}
                  </div>
                )}
              </div>
            );
          })}
          {groups.length === 0 && <p className="empty-state">No slots posted yet.</p>}
        </div>
      </div>
    </div>
  );
}
