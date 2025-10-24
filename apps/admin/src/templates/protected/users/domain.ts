import type { User as BaseUser } from '@sportipedia/user/domain/user';
import type { UserWithRole } from 'better-auth/plugins/admin';

export interface User extends BaseUser, UserWithRole {
  readonly role: 'user' | 'admin';
}
