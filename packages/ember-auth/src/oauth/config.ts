export interface Oauth2CodeGrantConfig {
  authorizeURL: string;
  clientId: string;
  redirectURI: string;
  scopes: string[];
}

export type SessionData = {
  state?: string;
  codeVerifier?: string;
};
