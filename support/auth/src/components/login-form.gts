import Component from '@glimmer/component';
import { fn, hash } from '@ember/helper';
import { service } from '@ember/service';

import { Await } from '@warp-drive/ember';
import { GithubProvider, persistOauthSessionData } from 'ember-auth';
import { command } from 'ember-command';
import { link } from 'ember-link';

import { Button, Form, Icon } from '@hokulea/ember';

import type { SessionService } from 'ember-auth';
import type { Link } from 'ember-link';

const ICONS: Record<string, string> = {
  github:
    '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><path fill="currentColor" d="M16 .396c-8.839 0-16 7.167-16 16c0 7.073 4.584 13.068 10.937 15.183c.803.151 1.093-.344 1.093-.772c0-.38-.009-1.385-.015-2.719c-4.453.964-5.391-2.151-5.391-2.151c-.729-1.844-1.781-2.339-1.781-2.339c-1.448-.989.115-.968.115-.968c1.604.109 2.448 1.645 2.448 1.645c1.427 2.448 3.744 1.74 4.661 1.328c.14-1.031.557-1.74 1.011-2.135c-3.552-.401-7.287-1.776-7.287-7.907c0-1.751.62-3.177 1.645-4.297c-.177-.401-.719-2.031.141-4.235c0 0 1.339-.427 4.4 1.641a15.4 15.4 0 0 1 4-.541c1.36.009 2.719.187 4 .541c3.043-2.068 4.381-1.641 4.381-1.641c.859 2.204.317 3.833.161 4.235c1.015 1.12 1.635 2.547 1.635 4.297c0 6.145-3.74 7.5-7.296 7.891c.556.479 1.077 1.464 1.077 2.959c0 2.14-.02 3.864-.02 4.385c0 .416.28.916 1.104.755c6.4-2.093 10.979-8.093 10.979-15.156c0-8.833-7.161-16-16-16z"/></svg>'
};

const PROVIDERS = [
  new GithubProvider({
    clientId: import.meta.env.GITHUB_CLIENT_ID as string,
    redirectURI: `http://localhost:4200/auth/github/callback`
  })
];

interface LoginFormSignature {
  Args: {
    registrationLink?: Link;
    resetPasswordLink?: Link;
  };
}

export class LoginForm extends Component<LoginFormSignature> {
  @service declare session: SessionService;

  get providers() {
    return Promise.all(
      PROVIDERS.map(async (p) => ({
        provider: p,
        icon: ICONS[p.name] as string,
        authorizationUrl: await p.generateCodeGrantURL().withPKCEChallenge()
      }))
    );
  }

  <template>
    <style>
      .divider {
        width: 55%;
        height: 1px;
        justify-self: center;
        margin-block: var(--spacing-container4);
        background-color: var(--control-border-color);
      }
    </style>
    <Await @promise={{this.providers}}>
      <:success as |providers|>
        {{#each providers as |p|}}
          <Button
            @importance="subtle"
            @push={{command
              (fn persistOauthSessionData p.authorizationUrl)
              (link (p.authorizationUrl.build))
            }}
          >
            <:before><Icon @icon={{p.icon}} /></:before>
            <:label>Login with
              {{p.provider.name}}</:label>
          </Button>
        {{/each}}
      </:success>
    </Await>

    <hr class="divider" />

    <Form @data={{hash email="" password=""}} as |f|>
      <f.Email @name="email" @label="Email" autocomplete="username" />
      <f.Password @name="password" @label="Password" autocomplete="current-password" />

      <f.Submit>Log in</f.Submit>
    </Form>
  </template>
}
