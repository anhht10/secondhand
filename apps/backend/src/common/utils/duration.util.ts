/**
 * Converts a duration string (e.g. '15m', '7d', '3600s', '2h') into milliseconds.
 */
export function parseDurationToMs(
  duration: string,
  defaultMs: number = 7 * 24 * 60 * 60 * 1000,
): number {
  const trimmed = duration.trim();
  const match = /^(\d+)\s*(ms|s|m|h|d)?$/i.exec(trimmed);
  if (!match) {
    return defaultMs;
  }
  const amount = parseInt(match[1], 10);
  const unit = (match[2] || 's').toLowerCase();

  switch (unit) {
    case 'ms':
      return amount;
    case 's':
      return amount * 1000;
    case 'm':
      return amount * 60 * 1000;
    case 'h':
      return amount * 60 * 60 * 1000;
    case 'd':
      return amount * 24 * 60 * 60 * 1000;
    default:
      return defaultMs;
  }
}

/**
 * Escapes special regular expression characters in user search input to prevent ReDoS / NoSQL injection.
 */
export function escapeRegex(input: string): string {
  return input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
