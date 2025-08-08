import { calculatePKCECodeChallenge, generateRandomCodeVerifier } from 'oauth4webapi';

import type { Oauth2CodeGrantConfig, SessionData } from './config.ts';

export class AuthorizeURL {
  #url: URL;
  #codeVerifier?: string;
  #state?: string;

  constructor(authorizeURL: string) {
    this.#url = new URL(authorizeURL);
  }

  static newCodeGrant({ authorizeURL, clientId, redirectURI, scopes }: Oauth2CodeGrantConfig) {
    return new AuthorizeURL(authorizeURL)
      .withCodeGrant()
      .withRedirectURI(redirectURI)
      .withClientId(clientId)
      .withScope(scopes);
  }

  withCodeGrant() {
    this.#state = crypto.randomUUID();

    this.#url.searchParams.set('response_type', 'code');
    this.#url.searchParams.set('state', this.#state);

    return this;
  }

  withResponseType(responseType: string) {
    this.#url.searchParams.set('response_type', responseType);

    return this;
  }

  withRedirectURI(redirectURI: string) {
    this.#url.searchParams.set('redirect_uri', redirectURI);

    return this;
  }

  withClientId(clientId: string) {
    this.#url.searchParams.set('client_id', clientId);

    return this;
  }

  withScope(scopes: string[]) {
    this.#url.searchParams.set('scope', scopes.join(' '));

    return this;
  }

  async withPKCEChallenge() {
    this.#codeVerifier = generateRandomCodeVerifier();

    const codeChallenge = await calculatePKCECodeChallenge(this.#codeVerifier);
    const codeChallengeMethod = 'S256';

    this.#url.searchParams.set('code_challenge', codeChallenge);
    this.#url.searchParams.set('code_challenge_method', codeChallengeMethod);

    return this;
  }

  build = () => {
    return this.#url.toString();
  };

  grabSessionData() {
    const data: SessionData = {};

    if (this.#codeVerifier) {
      data.codeVerifier = this.#codeVerifier;
    }

    if (this.#state) {
      data.state = this.#state;
    }

    return data;
  }
}
