import { AUTH_CONFIG } from '@sportipedia/user';
import { createAuthClient } from 'better-auth/client';
import { jwtClient } from 'better-auth/client/plugins';

export const auth = createAuthClient({
  ...AUTH_CONFIG,
  plugins: [jwtClient()]
});
