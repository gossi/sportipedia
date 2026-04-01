import { cached } from '@glimmer/tracking';

import { cell } from 'ember-resources';

import { auth } from '#/auth';

import type { Session } from 'ember-better-auth';

export class SessionsResource {
  #sessions = cell<Session[]>();

  get sessions() {
    return this.#sessions.current;
  }

  @cached
  get load() {
    // eslint-disable-next-line unicorn/consistent-function-scoping
    return async () => {
      const request = await auth.listSessions();

      if (request.data && request.data.length >= 0) {
        this.#sessions.set(request.data);
      }

      return request;
    };
  }

  revokeOtherSessions = async () => {
    await auth.revokeOtherSessions();

    await this.load();
  };
}

export async function revokeSessions() {
  await auth.revokeSessions();
  await auth.signOut();
}

export async function revokeSession(token: string) {
  await auth.revokeSession({ token });
}
