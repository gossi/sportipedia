import { BaseAuthenticator } from './base.ts';

import type { Authenticator } from './authenticator.ts';

export abstract class JWTAuthenticator<Payload = unknown, Data = unknown>
  extends BaseAuthenticator
  implements Authenticator<Payload, Data>
{
  abstract authenticate(data: Payload): Promise<Data>;

  invalidate(_data: Data, ..._args: unknown[]): Promise<void> {
    return Promise.resolve();
  }

  restore(data: Data): Promise<Data> {
    return Promise.resolve(data);
  }
}
