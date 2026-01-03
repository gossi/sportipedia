import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

import { SuccessPage } from '@sportipedia/ui';
import { t } from 'ember-intl';

import { FocusPage, Form } from '@hokulea/ember';

import type { AuthClient } from 'better-auth/client';

interface RequestPasswordResetSignature {
  Args: {
    auth: AuthClient<{ baseURL: string }>;
  };
}

export class RequestPasswordResetPage extends Component<RequestPasswordResetSignature> {
  @tracked requested = false;

  requestPasswordReset = async ({ email }: { email: string }): Promise<void> => {
    await this.args.auth.requestPasswordReset({
      email,
      redirectTo: 'http://localhost:4101/reset-password'
    });

    this.requested = true;
  };

  <template>
    {{#if this.requested}}
      <SuccessPage @title={{t "user.pages.request-password-reset.title"}}>
        {{t "user.pages.request-password-reset.success"}}
      </SuccessPage>
    {{else}}
      <FocusPage
        @title={{t "user.pages.request-password-reset.title"}}
        @description={{t "user.pages.request-password-reset.description"}}
      >
        <Form @submit={{this.requestPasswordReset}} as |f|>
          <f.Email @name="email" @label={{t "user.labels.email"}} />

          <f.Submit>
            {{t "user.pages.request-password-reset.actions.request-password"}}
          </f.Submit>
        </Form>
      </FocusPage>
    {{/if}}
  </template>
}
