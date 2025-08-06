import Service, { service } from '@ember/service';

import { calculatePKCECodeChallenge, generateRandomCodeVerifier } from 'oauth4webapi';

import CibGithub from '~icons/cib/github';

import type Store from './store';

type SessionParams = {
  state: string;
};

interface OauthProviderConfig {
  name: string;
  icon: string;
  authorizeUrl: string;
  clientId: string;
  redirectURI: string;
  scopes: string[];
}

class OauthProvider {
  #config: OauthProviderConfig;
  #codeVerifier: string;

  constructor(config: OauthProviderConfig) {
    this.#config = config;
    this.#codeVerifier = generateRandomCodeVerifier();
  }

  get name() {
    return this.#config.name;
  }

  get icon() {
    return this.#config.icon;
  }

  get codeVerifier() {
    return this.#codeVerifier;
  }

  async getAuthorizationURL() {
    const codeChallenge = await calculatePKCECodeChallenge(this.#codeVerifier);
    const codeChallengeMethod = 'S256';

    const loginUrl = new URL(this.#config.authorizeUrl);

    loginUrl.searchParams.set('client_id', this.#config.clientId);
    loginUrl.searchParams.set('code_challenge', codeChallenge);
    loginUrl.searchParams.set('code_challenge_method', codeChallengeMethod);
    loginUrl.searchParams.set('redirect_uri', this.#config.redirectURI);
    loginUrl.searchParams.set('response_type', 'code');
    loginUrl.searchParams.set('scope', this.#config.scopes.join(' '));

    return loginUrl;
  }
}

export function getOauthProviders() {
  return [
    new OauthProvider({
      name: 'github',
      icon: CibGithub,
      clientId: import.meta.env.GITHUB_CLIENT_ID as string,
      redirectURI: `http://localhost:4200/auth/github/callback`,
      scopes: ['read:user', 'user:email'],
      authorizeUrl: 'https://github.com/login/oauth/authorize'
    })
  ];
}

const STORAGE_KEY = 'sportipedia.code_verifier';

export default class SessionService extends Service {
  @service declare store: Store;

  storeCodeVerifier(provider: OauthProvider) {
    sessionStorage.setItem(STORAGE_KEY, provider.codeVerifier);
  }

  async authenticate(provider: string, code: string) {
    const response = await this.store.request({
      url: `http://localhost:4000/auth/${provider}/login`,
      method: 'POST',
      headers: new Headers({
        'Content-Type': 'application/json'
      }),
      body: JSON.stringify({
        code,
        session_params: {
          code_verifier: sessionStorage.getItem(STORAGE_KEY)
        }
      })
    });

    sessionStorage.removeItem(STORAGE_KEY);

    console.log(response);
  }
}
