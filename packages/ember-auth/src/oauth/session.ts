import type { AuthorizeURL } from './authorize-url.ts';
import type { SessionData } from './config.ts';

const STORAGE_KEY = 'ember-auth.oauth-session-data';

export function persistOauthSessionData(url: AuthorizeURL) {
  const sessionData = url.grabSessionData();

  sessionStorage.setItem(STORAGE_KEY, JSON.stringify(sessionData));
}

export function restoreOauthSessionData() {
  const data = sessionStorage.getItem(STORAGE_KEY) ?? '{}';
  const sessionData = JSON.parse(data) as SessionData;

  sessionStorage.removeItem(STORAGE_KEY);

  return sessionData;
}

export function verifyOauthSession(data: SessionData, params: URLSearchParams) {
  return data.state && params.has('state') && data.state === params.get('state');
}
