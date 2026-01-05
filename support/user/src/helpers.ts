import { ability } from 'ember-ability';

import type { User } from './domain/user';
import type { Session } from 'ember-better-auth';

export const getUser: () => User | undefined = ability(({ services }) => () => {
  return services.auth.user;
});

export const isAuthenticated: () => boolean = ability(({ services }) => () => {
  return services.auth.authenticated;
});

export const getSession: () => Session | undefined = ability(({ services }) => () => {
  return services.auth.session;
});
