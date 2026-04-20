import type { BetterAuthClientOptions } from 'better-auth/client';

export const AUTH_CONFIG: BetterAuthClientOptions = {
  baseURL: __AUTH_URL__,
  basePath: '/'
};
