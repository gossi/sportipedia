import { AUTH_CONFIG } from '@sportipedia/user';
import { createAuthClient } from 'better-auth/client';
import { adminClient } from 'better-auth/client/plugins';

export const auth = createAuthClient({
  ...AUTH_CONFIG,
  plugins: [adminClient()]
});
