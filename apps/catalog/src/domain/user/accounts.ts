import { cached } from '@glimmer/tracking';

import { cell } from 'ember-resources';

import { auth } from '#/auth';

import type { Account } from 'better-auth';

export class AccountsResource {
  #accounts = cell<Account[]>();

  get accounts() {
    return this.#accounts.current;
  }

  @cached
  get load() {
    return async () => {
      const request = await auth.listAccounts();

      if (request.data && request.data.length >= 0) {
        this.#accounts.set(request.data);
      }

      return request;
    };
  }

  usesProvider = (provider: string) => {
    return this.accounts.some((a) => a.providerId === provider);
  };

  linkSocial = async (provider: string) => {
    await auth.linkSocial({
      provider,
      callbackURL: globalThis.location.toString(),
      errorCallbackURL: globalThis.location.toString()
    });
  };

  unlinkSocial = async (provider: string) => {
    await auth.unlinkAccount({
      providerId: provider
    });

    this.#accounts.set(this.accounts.filter((a) => a.providerId !== provider));
  };
}
