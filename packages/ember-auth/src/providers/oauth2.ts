import { AuthorizeURL } from '../oauth/authorize-url.ts';

import type { Oauth2CodeGrantConfig } from '../oauth/config.ts';

export interface Oauth2ProviderMetaConfig {
  name: string;
}

export type Oauth2ProviderConfig = Oauth2ProviderMetaConfig & Oauth2CodeGrantConfig;

export class Oauth2Provider {
  #config: Oauth2ProviderConfig;

  constructor(config: Oauth2ProviderConfig) {
    this.#config = config;
  }

  get name() {
    return this.#config.name;
  }

  generateCodeGrantURL() {
    return AuthorizeURL.newCodeGrant(this.#config);
  }
}
