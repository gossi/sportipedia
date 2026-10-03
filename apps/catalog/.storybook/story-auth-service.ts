import { AuthService } from '@sportipedia/user';

import { auth } from '#auth/client';
import { ADMIN, GUEST, USER } from '#tests/user/support/fixtures';

import type { User } from '@sportipedia/user';
import type { Session } from 'ember-better-auth';

export const SESSIONS = {
  guest: GUEST,
  user: USER,
  admin: ADMIN
} as const;

export type SessionChoice = keyof typeof SESSIONS;

function makeSession(user: User): Session {
  const now = new Date();

  return {
    id: 'storybook-session',
    userId: user.id,
    token: 'storybook-jwt',
    createdAt: now,
    updatedAt: now,
    expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1000)
  };
}

/**
 * Auth service driven by the Storybook `session` toolbar global (or a
 * meta/story `globals: { session }` annotation) instead of the better-auth
 * network flow.
 */
export class StoryAuthService extends AuthService {
  override client = auth;

  // session state is applied via `setSession`, no network subscription
  override setup = (): void => {
    /* noop */
  };

  override subscribe(): void {
    /* events never fire for the storybook stub */
  }

  override unsubscribe(): void {
    /* events never fire for the storybook stub */
  }

  setSession(choice: SessionChoice): void {
    const user = SESSIONS[choice];

    this.internalData = user ? { user, session: makeSession(user) } : undefined;
  }
}
