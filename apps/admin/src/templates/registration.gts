import Component from '@glimmer/component';

import { RegistrationForm } from '@sportipedia/user';
import { t } from 'ember-intl';

import { Page } from '@hokulea/ember';

// import type { SessionService } from 'ember-auth';

export default class UserMenu extends Component {
  // @service declare session: SessionService;

  <template>
    <style>
      .registration {
        --sizing-max-content-width: 45rem;
        /*max-width: 50rem;*/
      }
    </style>
    <Page class="registration">
      <h1>{{t "accounts.pages.registration.heading"}}</h1>

      <div>
        <RegistrationForm />
      </div>

    </Page>
  </template>
}
