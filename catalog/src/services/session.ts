import Service, { service } from '@ember/service';

import type Store from './store';

type SessionParams = {
  state: string;
};

export default class SessionService extends Service {
  @service declare store: Store;

  async authenticate(provider: string, code: string, params: SessionParams) {
    const response = await this.store.request({
      url: `http://localhost:4000/api/v1/auth/${provider}/callback`,
      method: 'POST',
      headers: new Headers({
        'Content-Type': 'application/json'
      }),
      body: JSON.stringify({
        code,
        session_params: params
      })
    });

    console.log(response);
  }
}
