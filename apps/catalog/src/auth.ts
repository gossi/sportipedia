import { AUTH_CONFIG } from '@sportipedia/user';
import { createAuthClient } from 'better-auth/client';

export const auth = createAuthClient({
  ...AUTH_CONFIG,
  plugins: []
});
