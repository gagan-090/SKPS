/**
 * Rupee formatting shared across the web app — the counterpart of
 * `lib/core/utils/money.dart`.
 *
 * `formatINR` uses the ₹ glyph for on-screen use; `rupees` uses an "Rs" prefix
 * for the PDF, whose Helvetica font has no ₹ glyph.
 */

const grouped = new Intl.NumberFormat('en-IN', {
  minimumFractionDigits: 0,
  maximumFractionDigits: 2,
});

/** `1,250` — grouped digits, whole rupees without decimals. */
export function plain(value: number): string {
  return grouped.format(round2(value));
}

/** `₹1,250` — for on-screen use. */
export function formatINR(value: number): string {
  return `₹${plain(value)}`;
}

/** `Rs 1,250` — for the PDF, where ₹ is unavailable. */
export function rupees(value: number): string {
  return `Rs ${plain(value)}`;
}

/** A spreadsheet-friendly number: an integer when whole, else 2 dp. */
export function round2(value: number): number {
  return Math.round(value * 100) / 100;
}
