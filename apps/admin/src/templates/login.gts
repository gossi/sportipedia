import Component from '@glimmer/component';
import { service } from '@ember/service';

// import { LoginForm } from '#/components/login-form.gts';
import { LoginForm } from '@sportipedia/auth';

import { Page } from '@hokulea/ember';

import type { SessionService } from 'ember-auth';

export default class UserMenu extends Component {
  @service declare session: SessionService;

  <template>
    <style>
      .login {
        --sizing-max-content-width: 30rem;
      }
    </style>
    <Page class="login">
      <h1>Login</h1>
      <LoginForm />

    </Page>
  </template>
}
