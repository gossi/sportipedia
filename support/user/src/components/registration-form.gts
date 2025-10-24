import Component from '@glimmer/component';
import { service } from '@ember/service';

import { t } from 'ember-intl';
import * as v from 'valibot';

import { type FieldValidationHandler, Form } from '@hokulea/ember';

import type { AuthService } from '../services/auth.ts';
import type { Link } from 'ember-link';

const passwordSchema = v.pipe(
  v.optional(v.string(), ''),
  v.string(),
  v.minLength(8),
  v.regex(/[A-Z]/, 'upper'),
  v.regex(/[a-z]/, 'lower'),
  v.regex(/[0-9]/, 'number'),
  v.regex(/[^A-Za-z0-9]/, 'special')
);

interface RegistrationFormData {
  email: string;
  name: string;
  givenName: string;
  familyName: string;
  password: string;
  confirm_password: string;
}

const validateConfirmPassword: FieldValidationHandler<RegistrationFormData> = ({ value, form }) => {
  console.log('validateConfirmPassword', value, form.getFieldValue('password'));

  if (value !== form.getFieldValue('password')) {
    return 'Passwords must match';
  }

  return;
};

interface RegistrationFormSignature {
  Args: {
    registrationLink?: Link;
    resetPasswordLink?: Link;
  };
}

export class RegistrationForm extends Component<RegistrationFormSignature> {
  @service declare auth: AuthService;

  register = async (data: RegistrationFormData) => {
    data.name = `${data.givenName} ${data.familyName}`;

    const result = await this.auth.client.signUp.email(data);

    console.log(data, result);
  };

  <template>
    <Form @submit={{this.register}} as |f|>
      <f.Text
        @name="givenName"
        @label={{t "accounts.components.registration.form.givenName.label"}}
        @description={{t
          "accounts.components.registration.form.givenName.description"
          htmlSafe=true
        }}
        autocomplete="given-name"
        required
      />

      <f.Text
        @name="familyName"
        @label={{t "accounts.components.registration.form.familyName.label"}}
        @description={{t
          "accounts.components.registration.form.familyName.description"
          htmlSafe=true
        }}
        autocomplete="family-name"
        required
      />

      <f.Email
        @name="email"
        @label={{t "accounts.components.registration.form.email.label"}}
        autocomplete="email"
        required
      />

      <f.Password
        @name="password"
        @label={{t "accounts.components.registration.form.password.label"}}
        @validate={{passwordSchema}}
        autocomplete="new-password"
        required
      >
        <:rules as |Rule|>
          <Rule @key="type" @value="min_length">must be at least 8 characters</Rule>
          <Rule @key="message" @value="upper">must contain at least one uppercase letter</Rule>
          <Rule @key="message" @value="lower">must contain at least one lowercase letter</Rule>
          <Rule @key="message" @value="number">must contain at least one number</Rule>
          <Rule @key="message" @value="special">must contain at least one special character</Rule>
        </:rules>
      </f.Password>
      <f.Password
        @name="password_confirm"
        @label={{t "accounts.components.registration.form.password-confirm.label"}}
        @linkedField="password"
        @revalidateOn="input"
        @validate={{validateConfirmPassword}}
      />

      <f.Submit>{{t "accounts.components.registration.actions.register"}}</f.Submit>
    </Form>
  </template>
}
