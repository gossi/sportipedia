import Component from '@glimmer/component';
import { service } from '@ember/service';

import { LoginForm } from '@sportipedia/user';
import { t } from 'ember-intl';
import { link } from 'ember-link';

import { FocusPage } from '@hokulea/ember';

import type RouterService from '@ember/routing/router-service';

export default class Login extends Component {
  @service declare router: RouterService;

  redirect = () => {
    this.router.transitionTo('application');
  };

  <template>
    <FocusPage @title={{t "user.pages.login.heading"}}>
      <LoginForm
        @registrationLink={{link "registration"}}
        @resetPasswordLink={{link "request-password-reset"}}
        @callbackURL="http://localhost:4101"
        @success={{this.redirect}}
      />
    </FocusPage>
  </template>
}
