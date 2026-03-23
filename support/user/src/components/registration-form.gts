import Component from '@glimmer/component';
import { service } from '@ember/service';

import { t } from 'ember-intl';

import { Form } from '@hokulea/ember';

import { PasswordField, PasswordValidateField } from './password.gts';

import type { RegistrationFormData } from '../data/registration.ts';
import type { AuthService } from '../services/auth.ts';
import type { Link } from 'ember-link';

interface RegistrationFormSignature {
  Args: {
    registered?: () => void;
    registrationLink?: Link;
    resetPasswordLink?: Link;
  };
}

export class RegistrationForm extends Component<RegistrationFormSignature> {
  @service declare auth: AuthService;

  register = async (data: RegistrationFormData): Promise<void> => {
    data.name = `${data.givenName} ${data.familyName}`;

    const result = await this.auth.client.signUp.email(data);

    console.log(data, result);

    this.args.registered?.();
  };

  <template>
    <Form @submit={{this.register}} class="registration" as |f|>
      <f.Text
        @name="givenName"
        @label={{t "user.components.registration.form.givenName.label"}}
        autocomplete="given-name"
        required
      />

      <f.Text
        @name="familyName"
        @label={{t "user.components.registration.form.familyName.label"}}
        autocomplete="family-name"
        required
      />

      <f.Email
        @name="email"
        @label={{t "user.components.registration.form.email.label"}}
        autocomplete="email"
        required
      />

      <PasswordField @form={{f}} @name="password" required />
      <PasswordValidateField @form={{f}} @name="password_confirm" @linkedField="password" />

      <f.Submit>{{t "user.components.registration.actions.register"}}</f.Submit>
    </Form>
  </template>
}
