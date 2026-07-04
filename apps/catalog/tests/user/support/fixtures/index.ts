import type { User } from '@sportipedia/user';

export const USER: User = Object.freeze({
  email: 'max.mustermann@example.com',
  emailVerified: true,
  givenName: 'Max',
  familyName: 'Mustermann',
  role: 'user',
  id: '1',
  name: 'Max Mustermann',
  createdAt: new Date(),
  updatedAt: new Date()
});

export const ADMIN: User = Object.freeze({
  email: 'admin@example.com',
  emailVerified: true,
  givenName: 'Armin',
  familyName: 'Nistrator',
  role: 'admin',
  id: '1',
  name: 'Armin Nistrator',
  createdAt: new Date(),
  updatedAt: new Date()
});

export const GUEST = undefined;
