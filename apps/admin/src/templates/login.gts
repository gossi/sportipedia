import Component from '@glimmer/component';
import { cached } from '@glimmer/tracking';
import { fn, hash } from '@ember/helper';
import { on } from '@ember/modifier';
import { service } from '@ember/service';

import { Await } from '@warp-drive/ember';

import { getOauthProviders } from '#/services/session';

import { Form, Page } from '@hokulea/ember';

import type SessionService from '#/services/session';
import type Store from '#/services/store';

export default class UserMenu extends Component {
  @service declare store: Store;
  @service declare session: SessionService;

  @cached
  get providersRequest() {
    return this.store.request<{ data: [{ url: string; provider: string }] }>({
      url: 'http://localhost:4000/api/auth/providers'
    });
  }

  // get providers() {
  //   return getRequestState(this.providersRequest).value?.data;
  // }

  get providers() {
    return Promise.all(
      getOauthProviders().map(async (p) => ({
        provider: p,
        authorizationUrl: await p.getAuthorizationURL()
      }))
    );
  }

  <template>
    <Page>
      <h1>Login</h1>
      <Form @data={{hash email="" password=""}} as |f|>
        <f.Email @name="email" @label="Email" />
        <f.Password @name="password" @label="Password" />

        <f.Submit>Log in</f.Submit>
      </Form>

      <Await @promise={{this.providers}}>
        <:success as |providers|>
          {{#each providers as |p|}}
            <a
              href="{{p.authorizationUrl}}"
              {{on "click" (fn this.session.storeCodeVerifier p.provider)}}
            >Login with {{p.provider.name}}</a>
          {{/each}}
        </:success>
      </Await>

    </Page>
  </template>
}
