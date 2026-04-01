import { cached } from '@glimmer/tracking';

import { cell } from 'ember-resources';

import { auth } from '../../../auth.ts';

import type { User } from './domain.ts';

export class UserResource {
  #user = cell<User>();
  #userId;

  constructor(userId: string) {
    this.#userId = userId;
  }

  get user() {
    return this.#user.current;
  }

  @cached
  get load() {
    // eslint-disable-next-line unicorn/consistent-function-scoping
    return async () => {
      const request = await auth.admin.listUsers({
        query: {
          filterField: 'id',
          filterValue: this.#userId
        }
      });

      if (request.data && request.data.users.length >= 0) {
        this.#user.set(request.data.users[0] as User);
      }

      return request;
    };
  }

  changeName = async (id: string, data: Pick<User, 'givenName' | 'familyName'>) => {
    const request = await auth.admin.updateUser({
      userId: id,
      data: {
        ...data,
        name: `${data.givenName} ${data.familyName}`
      }
    });

    if (request.data) {
      this.#user.set(request.data as User);
    }
  };

  changeEmail = async (id: string, data: Pick<User, 'email'>) => {
    const request = await auth.admin.updateUser({
      userId: id,
      data
    });

    if (request.data) {
      this.#user.set(request.data as User);
    }
  };
}
