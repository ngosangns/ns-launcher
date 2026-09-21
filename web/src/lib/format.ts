export function formatPercent(value: number, digits = 0): string {
  return `${value < 0 ? "−" : "+"}${Math.abs(value * 100).toFixed(digits)}%`;
}

export function formatStatValue(type: string | null, value: number | null): string {
  if (value == null) return "—";
  if (type && /mastery|tinh thông/i.test(type)) return String(Math.round(value));
  if (Math.abs(value) <= 2) return formatPercent(value, value < 0.1 ? 1 : 0);
  return String(Math.round(value));
}

export function formatHP(value: number): string {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(2)}M`;
  if (value >= 10_000) return `${(value / 1_000).toFixed(1)}k`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(2)}k`;
  return String(Math.round(value));
}

export function formatDateRange(start: string, end: string, lang: "vi" | "en"): string {
  const opts: Intl.DateTimeFormatOptions = { day: "numeric", month: "short", year: "numeric" };
  const locale = lang === "vi" ? "vi-VN" : "en-GB";
  const a = new Date(`${start}T00:00:00`);
  const b = new Date(`${end}T00:00:00`);
  return `${a.toLocaleDateString(locale, opts)} – ${b.toLocaleDateString(locale, opts)}`;
}

export function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}
