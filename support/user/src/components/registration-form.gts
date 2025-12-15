import Component from '@glimmer/component';
import { fn } from '@ember/helper';
import { service } from '@ember/service';

import { t } from 'ember-intl';
import * as v from 'valibot';

import { type FieldValidationHandler, Form, type FormBuilder } from '@hokulea/ember';

import type { AuthService } from '../services/auth.ts';
import type { TOC } from '@ember/component/template-only';
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

// const validateConfirmPassword: FieldValidationHandler<RegistrationFormData> = ({ value, form }) => {
//   console.log('validateConfirmPassword', value, form.getFieldValue('password'));

//   if (value !== form.getFieldValue('password')) {
//     return 'Passwords must match';
//   }

//   return;
// };

function makePasswordValidator(linkedField: string) {
  const validateConfirmPassword: FieldValidationHandler<RegistrationFormData> = ({
    value,
    form
  }) => {
    console.log('validateConfirmPassword', value, form.getFieldValue(linkedField));

    if (value !== form.getFieldValue(linkedField)) {
      return 'Passwords must match';
    }

    return;
  };

  return validateConfirmPassword;
}

export const PasswordField: TOC<{
  Element: HTMLInputElement;
  Args: { form: FormBuilder<object>; name: string; label?: string };
}> = <template>
  <@form.Password
    @name={{@name}}
    @label={{if @label @label (t "user.components.registration.form.password.label")}}
    @validate={{passwordSchema}}
    autocomplete="new-password"
    ...attributes
  >
    <:rules as |Rule|>
      <Rule @key="type" @value="min_length">
        {{t "user.components.registration.form.password.rules.min-character"}}
      </Rule>
      <Rule @key="message" @value="upper">
        {{t "user.components.registration.form.password.rules.uppercase-letter"}}
      </Rule>
      <Rule @key="message" @value="lower">
        {{t "user.components.registration.form.password.rules.lowercase-letter"}}
      </Rule>
      <Rule @key="message" @value="number">
        {{t "user.components.registration.form.password.rules.number"}}
      </Rule>
      <Rule @key="message" @value="special">
        {{t "user.components.registration.form.password.rules.special-character"}}
      </Rule>
    </:rules>
  </@form.Password>
</template>;

export const PasswordValidateField: TOC<{
  Element: HTMLInputElement;
  Args: { form: FormBuilder<object>; name: string; label?: string; linkedField: string };
}> = <template>
  <@form.Password
    @name={{@name}}
    @label={{if @label @label (t "user.components.registration.form.password-confirm.label")}}
    @linkedField={{@linkedField}}
    @revalidateOn="input"
    {{! @glint-ignore }}
    @validate={{fn makePasswordValidator @linkedField}}
    autocomplete="new-password"
  />
</template>;

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
      {{!-- <f.Password
        @name="password"
        @label={{t "user.components.registration.form.password.label"}}
        @validate={{passwordSchema}}
        autocomplete="new-password"
        required
      >
        <:rules as |Rule|>
          <Rule @key="type" @value="min_length">
            {{t "user.components.registration.form.password.rules.min-character"}}
          </Rule>
          <Rule @key="message" @value="upper">
            {{t "user.components.registration.form.password.rules.uppercase-letter"}}
          </Rule>
          <Rule @key="message" @value="lower">
            {{t "user.components.registration.form.password.rules.lowercase-letter"}}
          </Rule>
          <Rule @key="message" @value="number">
            {{t "user.components.registration.form.password.rules.number"}}
          </Rule>
          <Rule @key="message" @value="special">
            {{t "user.components.registration.form.password.rules.special-character"}}
          </Rule>
        </:rules>
      </f.Password> --}}
      {{!-- <f.Password
        @name="password_confirm"
        @label={{t "user.components.registration.form.password-confirm.label"}}
        @linkedField="password"
        @revalidateOn="input"
        {{! @glint-ignore }}
        @validate={{validateConfirmPassword}}
        autocomplete="new-password"
      /> --}}

      <f.Submit>{{t "user.components.registration.actions.register"}}</f.Submit>
    </Form>
  </template>
}
