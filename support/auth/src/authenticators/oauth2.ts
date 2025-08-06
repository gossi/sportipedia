import { calculatePKCECodeChallenge, generateRandomCodeVerifier } from 'oauth4webapi';

import BaseAuthenticator from './base.ts';

import type { Authenticator } from './authenticator.ts';

export interface Oauth2ProviderConfig {
  name: string;
  authorizeUrl: string;
  clientId: string;
  redirectURI: string;
  scopes: string[];
}

const STORAGE_KEY = 'sportipedia.code_verifier';

export class Oauth2Authenticator extends BaseAuthenticator implements Authenticator {
  #config: Oauth2ProviderConfig;
  #codeVerifier: string;
  #authorizeURL!: URL;

  constructor(config: Oauth2ProviderConfig) {
    super();

    this.#config = config;
    this.#codeVerifier = generateRandomCodeVerifier();
  }

  async generateAuthorizationURL() {
    const codeChallenge = await calculatePKCECodeChallenge(this.#codeVerifier);
    const codeChallengeMethod = 'S256';

    const authorizeUrl = new URL(this.#config.authorizeUrl);

    authorizeUrl.searchParams.set('client_id', this.#config.clientId);
    authorizeUrl.searchParams.set('code_challenge', codeChallenge);
    authorizeUrl.searchParams.set('code_challenge_method', codeChallengeMethod);
    authorizeUrl.searchParams.set('redirect_uri', this.#config.redirectURI);
    authorizeUrl.searchParams.set('response_type', 'code');
    authorizeUrl.searchParams.set('scope', this.#config.scopes.join(' '));

    return authorizeUrl;
  }

  get name() {
    return this.#config.name;
  }

  get codeVerifier() {
    return this.#codeVerifier;
  }

  get authorizeURL() {
    return this.#authorizeURL;
  }

  storeChecksum() {
    sessionStorage.setItem(STORAGE_KEY, this.#codeVerifier);
  }

  async authenticate({ code }: { code: string }) {
    const codeVerifier = sessionStorage.getItem(STORAGE_KEY);
    const response = await fetch(`http://localhost:4000/auth/${this.#config.name}/login`, {
      method: 'POST',
      headers: new Headers({
        'Content-Type': 'application/json'
      }),
      body: JSON.stringify({
        code,
        session_params: {
          code_verifier: codeVerifier
        }
      })
    });

    sessionStorage.removeItem(STORAGE_KEY);

    console.log(response);

    return '';
  }

  invalidate(): Promise<void> {
    return Promise.resolve();
  }

  restore(): Promise<void> {
    return Promise.resolve();
  }
}
