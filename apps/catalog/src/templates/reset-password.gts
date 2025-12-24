import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

import { PasswordField, PasswordValidateField } from '@sportipedia/user';
import { t } from 'ember-intl';
import { link } from 'ember-link';

import { auth } from '#/auth';
import { ErrorPage, SuccessPage } from '#/components/notification-pages.gts';

import { Button, FocusPage, Form } from '@hokulea/ember';

import type Owner from '@ember/owner';

export default class ResetPassword extends Component {
  @tracked state = 'change';
  @tracked errorCode: string | undefined;

  token?: string;

  constructor(owner: Owner, args: object) {
    super(owner, args);

    const params = new URLSearchParams(globalThis.location.search);
    const token = params.get('token');

    if (token) {
      this.token = token;
    } else {
      this.errorCode = 'NO_TOKEN';
    }
  }

  get change() {
    return this.state === 'change';
  }

  get success() {
    return this.state === 'success';
  }

  get error() {
    return this.state === 'error' || this.errorCode !== undefined;
  }

  get errorInvalidToken() {
    return this.errorCode === 'INVALID_TOKEN';
  }

  get errorNoToken() {
    return this.errorCode === 'NO_TOKEN';
  }

  resetPassword = async ({ password }: { password: string }) => {
    const { error } = await auth.resetPassword({
      newPassword: password,
      token: this.token
    });

    if (error) {
      this.errorCode = error.code as string;
    }

    this.state = error ? 'error' : 'success';
  };

  <template>
    {{#if this.error}}
      <ErrorPage @title={{t "user.pages.reset-password.title"}}>
        <:content>
          {{#if this.errorNoToken}}
            {{t "user.pages.reset-password.errors.no-token"}}
          {{else if this.errorInvalidToken}}
            {{t "user.pages.reset-password.errors.invalid-token"}}
          {{else}}
            {{t "user.pages.reset-password.errors.unknown"}}
          {{/if}}
        </:content>
        <:actions>
          <Button @push={{link "/request-password-reset"}}>
            {{t "user.pages.reset-password.actions.redo"}}
          </Button>
        </:actions>
      </ErrorPage>
    {{else if this.change}}
      <FocusPage @title={{t "user.pages.reset-password.title"}}>
        <Form @submit={{this.resetPassword}} as |f|>
          <PasswordField @form={{f}} @name="password" @label={{t "user.labels.new-password"}} />
          <PasswordValidateField @form={{f}} @name="password_confirm" @linkedField="password" />

          <f.Submit>{{t "user.pages.reset-password.actions.set-password"}}</f.Submit>
        </Form>
      </FocusPage>
    {{else if this.success}}
      <SuccessPage @title={{t "user.pages.reset-password.title"}}>
        <:content>
          {{t "user.pages.reset-password.success"}}
        </:content>
        <:actions>
          <Button @push={{link "/login"}}>{{t "user.pages.reset-password.actions.login"}}</Button>
        </:actions>
      </SuccessPage>
    {{/if}}
  </template>
}
