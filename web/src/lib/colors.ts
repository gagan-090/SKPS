/** Palette values that JS needs at runtime, from `app_colors.dart`. */

export const StatusColor = {
  present: '#16A34A',
  absent: '#DC2626',
  half_day: '#F59E0B',
  leave: '#6366F1',
  notMarked: '#9CA3AF',
} as const;

/** Deterministic avatar tints, so the same person always keeps the same colour. */
const AVATAR_PALETTE = [
  '#1B4D3E', '#0E7490', '#4338CA', '#9D174D', '#92400E',
  '#3F6212', '#6D28D9', '#9F1239', '#115E59', '#1E40AF',
];

export function avatarFor(seed: string): string {
  const s = seed.trim().toLowerCase();
  if (!s) return AVATAR_PALETTE[0];
  let hash = 0;
  for (let i = 0; i < s.length; i++) {
    hash = (hash * 31 + s.charCodeAt(i)) & 0x7fffffff;
  }
  return AVATAR_PALETTE[hash % AVATAR_PALETTE.length];
}

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
