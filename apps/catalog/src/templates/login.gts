import Component from '@glimmer/component';
import { cached } from '@glimmer/tracking';
import { hash } from '@ember/helper';
import { service } from '@ember/service';

import { getRequestState } from '@warp-drive/ember';

import { Form, Page } from '@hokulea/ember';

import type Store from '#/services/store';

export default class UserMenu extends Component {
  @service declare store: Store;

  @cached
  get providersRequest() {
    return this.store.request<{ data: [{ url: string; provider: string }] }>({
      url: 'http://localhost:4000/api/auth/providers'
    });
  }

  get providers() {
    return getRequestState(this.providersRequest).value?.data;
  }

  <template>
    <Page>
      <h1>Login</h1>
      <Form @data={{hash email="" password=""}} as |f|>
        <f.Email @name="email" @label="Email" />
        <f.Password @name="password" @label="Password" />

        <f.Submit>Log in</f.Submit>
      </Form>
      {{#if this.providers}}
        {{#each this.providers as |p|}}
          <a href="{{p.url}}">Login with {{p.provider}}</a>
        {{/each}}
      {{/if}}
    </Page>
  </template>
}
