import { useEffect, useMemo, useRef, useState } from "react";
import { TeacherApi } from "../../api/endpoints";
import { fmtTime, fmtTimeRange, isoToLocalInput, localInputToIso } from "../../utils/format";
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

const emptyDayTimes = () => ({});

export default function TeacherSlots() {
  const [approvedCourses, setApprovedCourses] = useState([]);
  const [slots, setSlots] = useState([]);
  const [mode, setMode] = useState("weekly");
  const [error, setError] = useState("");
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
    dayTimes: emptyDayTimes(),
    startDate: todayInputValue(),
    endDate: "",
  });
  const [weeklyResult, setWeeklyResult] = useState(null);

  async function load() {
    const [apps, mySlots] = await Promise.all([TeacherApi.myApplications(), TeacherApi.mySlots()]);
    setApprovedCourses(apps.filter((a) => a.status === "APPROVED"));
    setSlots(mySlots);
    // Jump the schedule view to the earliest upcoming slot once, on first load, so it opens
    // showing real slots instead of "today" if nothing's posted for today specifically.
    if (!calendarInitialized.current) {
      const active = mySlots.filter((s) => !s.cancelled);
      const now = new Date();
      const upcoming = active.map((s) => new Date(s.startTime)).filter((d) => d >= now);
      if (upcoming.length) {
        setViewedDate(upcoming.sort((a, b) => a - b)[0]);
        calendarInitialized.current = true;
      }
    }
  }

  useEffect(() => {
    load();
  }, []);

  // A teacher may only have one active slot (or series) per course — find it, if any, so the
  // "single slot" form can switch from create to edit, and the weekly form can be gated off.
  const activeSlotForSingleCourse = useMemo(
    () => slots.find((s) => !s.cancelled && String(s.courseId) === String(singleForm.courseId)),
    [slots, singleForm.courseId]
  );
  const activeSlotForWeeklyCourse = useMemo(
    () => slots.find((s) => !s.cancelled && String(s.courseId) === String(weeklyForm.courseId)),
    [slots, weeklyForm.courseId]
  );

  // Keep the single-slot form in sync with whichever slot is currently active for the chosen
  // course, so switching courses (or just having created/updated a slot) shows its real values.
  useEffect(() => {
    if (!activeSlotForSingleCourse) return;
    setSingleForm((f) => ({
      ...f,
      startTime: isoToLocalInput(activeSlotForSingleCourse.startTime),
      endTime: isoToLocalInput(activeSlotForSingleCourse.endTime),
      capacity: activeSlotForSingleCourse.capacity,
    }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeSlotForSingleCourse?.id, activeSlotForSingleCourse?.startTime, activeSlotForSingleCourse?.endTime, activeSlotForSingleCourse?.capacity]);

  function updateSingle(field, value) {
    setSingleForm((f) => ({ ...f, [field]: value }));
  }

  function updateWeekly(field, value) {
    setWeeklyForm((f) => ({ ...f, [field]: value }));
  }

  function toggleWeekday(days) {
    setWeeklyForm((f) => {
      const dayTimes = { ...f.dayTimes };
      // Drop times for days that just got deselected; leave the rest untouched.
      Object.keys(dayTimes).forEach((d) => {
        if (!days.includes(Number(d))) delete dayTimes[d];
      });
      const nextClassesPerWeek = Math.min(f.classesPerWeek, days.length) || (days.length ? 1 : 0);
      return { ...f, weekdays: days, dayTimes, classesPerWeek: nextClassesPerWeek };
    });
  }

  function updateDayTime(day, field, value) {
    setWeeklyForm((f) => ({
      ...f,
      dayTimes: { ...f.dayTimes, [day]: { ...f.dayTimes[day], [field]: value } },
    }));
  }

  async function createSingleSlot(e) {
    e.preventDefault();
    setError("");
    setBusy(true);
    const payload = {
      courseId: Number(singleForm.courseId),
      startTime: localInputToIso(singleForm.startTime),
      endTime: localInputToIso(singleForm.endTime),
      capacity: Number(singleForm.capacity) || 1,
    };
    try {
      if (activeSlotForSingleCourse) {
        await TeacherApi.updateSlot(activeSlotForSingleCourse.id, payload);
      } else {
        await TeacherApi.createSlot(payload);
      }
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
    setWeeklyResult(null);
    if (weeklyForm.weekdays.length === 0) {
      setError("Pick at least one day of the week.");
      return;
    }
    for (const day of weeklyForm.weekdays) {
      const t = weeklyForm.dayTimes[day];
      if (!t?.start || !t?.end) {
        setError(`Set a start and end time for ${DAY_LABEL[day]}.`);
        return;
      }
      if (t.end <= t.start) {
        setError(`End time must be after start time for ${DAY_LABEL[day]}.`);
        return;
      }
    }
    if (!weeklyForm.endDate) {
      setError("Pick a repeat-until date.");
      return;
    }
    if (weeklyForm.endDate < weeklyForm.startDate) {
      setError("Repeat-until date must be on or after the start date.");
      return;
    }
    const classesPerWeek = Number(weeklyForm.classesPerWeek);
    if (!classesPerWeek || classesPerWeek < 1 || classesPerWeek > weeklyForm.weekdays.length) {
      setError(`Classes per week must be between 1 and ${weeklyForm.weekdays.length} (the number of days you offered).`);
      return;
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
        dayWindows: weeklyForm.weekdays.map((d) => ({
          dayOfWeek: JS_DAY_TO_JAVA_DAY[d],
          startTime: weeklyForm.dayTimes[d].start,
          endTime: weeklyForm.dayTimes[d].end,
        })),
      });
      setWeeklyResult({ created: created.length });
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function cancelSlot(id) {
    await TeacherApi.cancelSlot(id);
    load();
  }

  async function cancelSeries(recurrenceGroupId) {
    if (!confirm("Cancel every remaining slot in this weekly series?")) return;
    await TeacherApi.cancelSlotSeries(recurrenceGroupId);
    load();
  }

  return (
    <div className="page">
      <h1>My slots</h1>
      <p className="page-subtitle">Set your weekly availability, or add a one-off slot, for courses you're approved to teach.</p>

      {approvedCourses.length === 0 ? (
        <p className="empty-state">You don't have any approved courses yet. Apply to a course and wait for Admin approval.</p>
      ) : (
        <div className="card form-card">
          <div className="btn-group slot-mode-toggle">
            <button
              type="button"
              className={`btn btn-sm ${mode === "weekly" ? "btn-primary" : "btn-ghost"}`}
              onClick={() => setMode("weekly")}
            >
              Weekly availability
            </button>
            <button
              type="button"
              className={`btn btn-sm ${mode === "single" ? "btn-primary" : "btn-ghost"}`}
              onClick={() => setMode("single")}
            >
              Single slot
            </button>
          </div>

          {error && <div className="banner banner-error">{error}</div>}

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
                  <div className="btn-group">
                    <button
                      type="button"
                      className={`btn btn-sm ${weeklyForm.sessionType === "ONE_ON_ONE" ? "btn-primary" : "btn-ghost"}`}
                      onClick={() => updateWeekly("sessionType", "ONE_ON_ONE")}
                    >
                      1-on-1
                    </button>
                    <button
                      type="button"
                      className={`btn btn-sm ${weeklyForm.sessionType === "GROUP" ? "btn-primary" : "btn-ghost"}`}
                      onClick={() => updateWeekly("sessionType", "GROUP")}
                    >
                      Group
                    </button>
                  </div>
                </div>
              </div>

              {weeklyForm.courseId && activeSlotForWeeklyCourse ? (
                <div className="banner banner-warn">
                  This course already has an active {activeSlotForWeeklyCourse.recurrenceGroupId ? "weekly plan" : "slot"}. Cancel it under
                  "Your posted slots" below before creating a new one.
                </div>
              ) : (
                <>
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
                    <input
                      type="number"
                      min="1"
                      value={weeklyForm.capacity}
                      onChange={(e) => updateWeekly("capacity", e.target.value)}
                    />
                  </div>
                )}
              </div>

              <label>Which days are you free for this course?</label>
              <WeekdayPicker selected={weeklyForm.weekdays} onChange={toggleWeekday} />

              {weeklyForm.weekdays.length > 0 && (
                <div className="day-window-list">
                  {weeklyForm.weekdays.map((day, idx) => {
                    const prevDay = idx > 0 ? weeklyForm.weekdays[idx - 1] : null;
                    const prevTimes = prevDay != null ? weeklyForm.dayTimes[prevDay] : null;
                    const canCopy = prevTimes?.start && prevTimes?.end;
                    return (
                      <div className="day-window-row" key={day}>
                        <span className="day-window-label">{DAY_LABEL[day]}</span>
                        <input
                          type="time"
                          required
                          value={weeklyForm.dayTimes[day]?.start || ""}
                          onChange={(e) => updateDayTime(day, "start", e.target.value)}
                        />
                        <span>to</span>
                        <input
                          type="time"
                          required
                          value={weeklyForm.dayTimes[day]?.end || ""}
                          onChange={(e) => updateDayTime(day, "end", e.target.value)}
                        />
                        {prevDay != null && (
                          <button
                            type="button"
                            className="btn btn-ghost btn-sm day-window-copy"
                            disabled={!canCopy}
                            title={canCopy ? `Copy ${DAY_LABEL[prevDay]}'s time` : `Set ${DAY_LABEL[prevDay]}'s time first`}
                            onClick={() => {
                              updateDayTime(day, "start", prevTimes.start);
                              updateDayTime(day, "end", prevTimes.end);
                            }}
                          >
                            Same as {DAY_LABEL[prevDay]}
                          </button>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}

              <div className="form-row">
                <div>
                  <label>Repeat from</label>
                  <input
                    type="date"
                    required
                    min={todayInputValue()}
                    value={weeklyForm.startDate}
                    onChange={(e) => updateWeekly("startDate", e.target.value)}
                  />
                </div>
                <div>
                  <label>Repeat until</label>
                  <input
                    type="date"
                    required
                    value={weeklyForm.endDate}
                    onChange={(e) => updateWeekly("endDate", e.target.value)}
                  />
                </div>
              </div>

              <p className="form-hint">
                A slot is created for every day above, at that day's own time range. Students will pick{" "}
                {weeklyForm.classesPerWeek || "N"} of your offered day{weeklyForm.weekdays.length === 1 ? "" : "s"} per week.
              </p>

              {weeklyResult && (
                <div className="banner banner-info">
                  Created {weeklyResult.created} slot{weeklyResult.created === 1 ? "" : "s"}.
                </div>
              )}

              <button className="btn btn-primary" type="submit" disabled={busy}>
                {busy ? "Creating slots..." : "Create weekly availability"}
              </button>
                </>
              )}
            </form>
          )}

          {mode === "single" && (
            <form onSubmit={createSingleSlot}>
              <div className="form-row">
                <div>
                  <label>Course</label>
                  <select required value={singleForm.courseId} onChange={(e) => updateSingle("courseId", e.target.value)}>
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
                  <input type="number" min="1" value={singleForm.capacity} onChange={(e) => updateSingle("capacity", e.target.value)} />
                </div>
              </div>

              {activeSlotForSingleCourse && (
                <div className="banner banner-warn">You already have an active slot for this course — editing it below instead of creating a new one.</div>
              )}

              <div className="form-row">
                <div>
                  <label>Start time</label>
                  <input
                    type="datetime-local"
                    required
                    value={singleForm.startTime}
                    onChange={(e) => updateSingle("startTime", e.target.value)}
                  />
                </div>
                <div>
                  <label>End time</label>
                  <input
                    type="datetime-local"
                    required
                    value={singleForm.endTime}
                    onChange={(e) => updateSingle("endTime", e.target.value)}
                  />
                </div>
              </div>
              <button className="btn btn-primary" type="submit" disabled={busy}>
                {busy ? (activeSlotForSingleCourse ? "Updating..." : "Adding...") : activeSlotForSingleCourse ? "Update slot" : "Add slot"}
              </button>
            </form>
          )}
        </div>
      )}

      <div className="section">
        <h2>Your schedule</h2>
        {slots.filter((s) => !s.cancelled).length === 0 ? (
          <p className="empty-state">No slots posted yet.</p>
        ) : (
          <DayCalendar
            date={viewedDate}
            onDateChange={setViewedDate}
            items={slots.filter((s) => !s.cancelled)}
            dateField="startTime"
            endField="endTime"
            emptyText="No slots this day"
            renderItem={(s) => (
              <div className={`week-slot-chip teacher-slot-chip ${s.full ? "full" : ""}`}>
                <span className="week-slot-time">{s.courseTitle}</span>
                <span className="week-slot-cap">
                  {fmtTime(s.startTime)}–{fmtTime(s.endTime)} · {s.bookedCount}/{s.capacity}
                  {s.recurrenceGroupId ? " · Series" : ""}
                </span>
              </div>
            )}
          />
        )}
      </div>

      <div className="section">
        <h2>Manage slots</h2>
        <div className="card-list">
          {slots.map((s) => (
            <div className="card" key={s.id}>
              <div className="card-row">
                <div className="card-row-main">
                  <div className="card-title" title={s.courseTitle}>
                    {s.courseTitle}
                    {s.recurrenceGroupId && <span className="pill small">Series</span>}
                    <span className="pill small">{s.sessionType === "GROUP" ? "Group" : "1-on-1"}</span>
                  </div>
                  <div className="card-sub">{fmtTimeRange(s.startTime, s.endTime)}</div>
                  <div className="card-sub">
                    {s.bookedCount}/{s.capacity} booked{s.cancelled ? " · cancelled" : ""}
                    {s.classesPerWeek > 0 ? ` · ${s.classesPerWeek} classes/week required` : ""}
                  </div>
                </div>
                {!s.cancelled && (
                  <div className="btn-group">
                    <button className="btn btn-ghost btn-sm" onClick={() => cancelSlot(s.id)}>
                      Cancel
                    </button>
                    {s.recurrenceGroupId && (
                      <button className="btn btn-ghost btn-sm" onClick={() => cancelSeries(s.recurrenceGroupId)}>
                        Cancel series
                      </button>
                    )}
                  </div>
                )}
              </div>
            </div>
          ))}
          {slots.length === 0 && <p className="empty-state">No slots posted yet.</p>}
        </div>
      </div>
    </div>
  );
}
