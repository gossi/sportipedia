/**
 * @module Accounts
 * @category Domain Objects
 */
import { cached } from '@glimmer/tracking';

import { cell } from 'ember-resources';

import { auth } from '#auth/client';

import type { Account } from 'better-auth';

/**
 * @group Accounts
 * @category Accounts
 */
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
    const account = this.accounts.find((a) => a.providerId === provider);

    if (!account) return;

    await auth.unlinkAccount({ accountId: account.id });

    this.#accounts.set(this.accounts.filter((a) => a.providerId !== provider));
  };
}
