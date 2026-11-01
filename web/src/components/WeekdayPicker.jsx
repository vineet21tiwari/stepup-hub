const DAYS = [
  { value: 0, label: "Sun" },
  { value: 1, label: "Mon" },
  { value: 2, label: "Tue" },
  { value: 3, label: "Wed" },
  { value: 4, label: "Thu" },
  { value: 5, label: "Fri" },
  { value: 6, label: "Sat" },
];

// Multi-select weekday chips (0 = Sunday, matching Date.getDay()).
export default function WeekdayPicker({ selected, onChange }) {
  function toggle(day) {
    onChange(selected.includes(day) ? selected.filter((d) => d !== day) : [...selected, day].sort());
  }

  return (
    <div className="weekday-picker">
      {DAYS.map((d) => (
        <button
          type="button"
          key={d.value}
          className={`weekday-chip ${selected.includes(d.value) ? "active" : ""}`}
          onClick={() => toggle(d.value)}
        >
          {d.label}
        </button>
      ))}
    </div>
  );
}
