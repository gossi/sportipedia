import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

import { ErrorPage, SuccessPage } from '@sportipedia/ui';
import { t } from 'ember-intl';

import { Button, FocusPage, Form } from '@hokulea/ember';

import { PasswordField, PasswordValidateField } from '../components/password.gts';

import type Owner from '@ember/owner';
import type { AuthClient } from 'better-auth/client';
import type { Link } from 'ember-link';

interface ResetPasswordSignature {
  Args: {
    auth: AuthClient<{ baseURL: string }>;
    loginLink: Link;
    requestPasswordResetLink: Link;
  };
}

export class ResetPasswordPage extends Component<ResetPasswordSignature> {
  @tracked state = 'change';
  @tracked errorCode: string | undefined;

  token?: string;

  constructor(owner: Owner, args: ResetPasswordSignature['Args']) {
    super(owner, args);

    const params = new URLSearchParams(globalThis.location.search);
    const token = params.get('token');

    if (token) {
      this.token = token;
    } else {
      this.errorCode = 'NO_TOKEN';
    }
  }

  get change(): boolean {
    return this.state === 'change';
  }

  get success(): boolean {
    return this.state === 'success';
  }

  get error(): boolean {
    return this.state === 'error' || this.errorCode !== undefined;
  }

  get errorInvalidToken(): boolean {
    return this.errorCode === 'INVALID_TOKEN';
  }

  get errorNoToken(): boolean {
    return this.errorCode === 'NO_TOKEN';
  }

  resetPassword = async ({ password }: { password: string }): Promise<void> => {
    const { error } = await this.args.auth.resetPassword({
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
          <Button @push={{@requestPasswordResetLink}}>
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
          <Button @push={{@loginLink}}>{{t "user.pages.reset-password.actions.login"}}</Button>
        </:actions>
      </SuccessPage>
    {{/if}}
  </template>
}
