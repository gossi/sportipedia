import type { BetterAuthUser } from 'ember-better-auth';

export interface User extends BetterAuthUser {
  name: string;
  givenName: string;
  familyName: string;
  email: string;
  emailVerified: boolean;
  readonly role: 'user' | 'admin';
}

export function isAdmin(user: User): boolean {
  return user.role === 'admin';
}
