import { JWTAuthenticator } from 'ember-auth';

interface Payload {
  provider: string;
  code: string;
  codeVerifier: string;
}

interface Data {
  token: string;
}

export class SportipediaOauthAuthenticator<
  P extends Payload = Payload,
  D extends Data = Data
> extends JWTAuthenticator<P, D> {
  async authenticate({ provider, code, codeVerifier }: P) {
    const response = await fetch(`http://localhost:4000/auth/${provider}/login`, {
      method: 'POST',
      headers: new Headers({
        'Content-Type': 'application/json'
      }),
      body: JSON.stringify({
        code: code,
        session_params: {
          code_verifier: codeVerifier
        }
      })
    });

    return (await response.json()) as D;
  }

  async invalidate(_data: D, ..._args: unknown[]): Promise<void> {}
}
