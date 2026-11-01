import { useTheme } from "../context/ThemeContext";

const OPTIONS = [
  { value: "light", icon: "☀️", label: "Light" },
  { value: "dark", icon: "🌙", label: "Dark" },
  { value: "auto", icon: "🖥️", label: "Auto" },
];

export default function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <div className="theme-toggle" role="group" aria-label="Theme">
      {OPTIONS.map((o) => (
        <button
          key={o.value}
          type="button"
          className={`theme-toggle-btn ${theme === o.value ? "active" : ""}`}
          title={o.label}
          aria-label={o.label}
          onClick={() => setTheme(o.value)}
        >
          {o.icon}
        </button>
      ))}
    </div>
  );
}
