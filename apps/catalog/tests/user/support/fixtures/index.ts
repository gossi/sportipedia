import type { User } from '@sportipedia/user';

export const USER: User = Object.freeze({
  id: '1',
  givenName: 'Max',
  familyName: 'Mustermann',
  name: 'Max Mustermann',
  email: 'max.mustermann@example.com',
  emailVerified: true,
  role: 'user',
  lang: 'en',
  createdAt: new Date(),
  updatedAt: new Date()
});

export const ADMIN: User = Object.freeze({
  id: '1',
  givenName: 'Armin',
  familyName: 'Nistrator',
  name: 'Armin Nistrator',
  email: 'admin@example.com',
  emailVerified: true,
  role: 'admin',
  lang: 'en',
  createdAt: new Date(),
  updatedAt: new Date()
});

export const GUEST = undefined;
