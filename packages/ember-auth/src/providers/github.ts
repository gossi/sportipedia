import { Oauth2Provider, type Oauth2ProviderConfig } from './oauth2.ts';

const GITHUB_DEFAULT_CONFIG = {
  name: 'github',
  scopes: ['read:user', 'user:email'],
  authorizeURL: 'https://github.com/login/oauth/authorize'
};

type GithubConfig = Partial<Omit<Oauth2ProviderConfig, 'name'>> &
  Required<Pick<Oauth2ProviderConfig, 'clientId' | 'redirectURI'>>;

export class GithubProvider extends Oauth2Provider {
  constructor(config: GithubConfig) {
    super({
      ...GITHUB_DEFAULT_CONFIG,
      ...config
    });
  }
}
