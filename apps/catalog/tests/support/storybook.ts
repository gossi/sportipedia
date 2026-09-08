export const CUSTOM = '[Custom]';

export function withCustom(options: unknown[]) {
  return [CUSTOM, ...options];
}
