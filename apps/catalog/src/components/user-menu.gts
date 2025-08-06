import Component from '@glimmer/component';
import { cached } from '@glimmer/tracking';
import { service } from '@ember/service';

import { getRequestState } from '@warp-drive/ember';

import type Store from '#/services/store';

export default class UserMenu extends Component {
  @service declare store: Store;

  req = {
    url: 'http://localhost:4000/api/v1/auth/github/new'
  };

  @cached
  get authRequest() {
    return this.store.request<{ data: { url: string } }>({
      url: 'http://localhost:4000/api/v1/auth/github/new'
    });
  }

  get auth() {
    return getRequestState(this.authRequest).value?.data;
  }

  <template>
    {{#if this.auth}}
      <a href="{{this.auth.url}}">Login with Github</a>
    {{/if}}
  </template>
}
