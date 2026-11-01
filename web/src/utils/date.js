// The platform's calendar/booking logic is anchored to India Standard Time everywhere (see
// backend AppTime.ZONE and utils/format.js) — every helper here reads "which day/hour" an instant
// falls on via IST, not the browser's own timezone, so the Day Calendar positions events correctly
// and "today"/day-bucketing stay consistent regardless of the viewer's device.
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

// Shifts an instant so reading it back with getUTC* getters yields IST wall-clock components.
function toIst(date) {
  return new Date(date.getTime() + IST_OFFSET_MS);
}

export function startOfDay(date) {
  const ist = toIst(date);
  ist.setUTCHours(0, 0, 0, 0);
  return new Date(ist.getTime() - IST_OFFSET_MS);
}

// Pure millisecond arithmetic — timezone/DST-agnostic, so "add N days" is always exactly N*24h.
export function addDays(date, n) {
  return new Date(date.getTime() + n * 24 * 60 * 60 * 1000);
}

export function sameDay(a, b) {
  const ia = toIst(a);
  const ib = toIst(b);
  return ia.getUTCFullYear() === ib.getUTCFullYear() && ia.getUTCMonth() === ib.getUTCMonth() && ia.getUTCDate() === ib.getUTCDate();
}

// YYYY-MM-DD for the IST calendar day this instant falls on.
export function toDateInputValue(date) {
  const ist = toIst(date);
  const pad = (n) => String(n).padStart(2, "0");
  return `${ist.getUTCFullYear()}-${pad(ist.getUTCMonth() + 1)}-${pad(ist.getUTCDate())}`;
}

// Minutes since IST midnight — used to position an instant on an hourly day-view grid.
export function minutesSinceMidnightIst(date) {
  const ist = toIst(date);
  return ist.getUTCHours() * 60 + ist.getUTCMinutes();
}

// 0 (Sunday) .. 6 (Saturday) for the IST calendar day this instant falls on.
export function dayOfWeekIst(date) {
  return toIst(date).getUTCDay();
}
