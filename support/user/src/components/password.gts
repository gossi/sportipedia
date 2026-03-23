import { t } from 'ember-intl';
import * as v from 'valibot';

import type { RegistrationFormData } from '../data/registration';
import type { TOC } from '@ember/component/template-only';
import type { FieldValidationHandler, FormBuilder } from '@hokulea/ember';

const passwordSchema = v.pipe(
  v.optional(v.string(), ''),
  v.string(),
  v.minLength(8),
  v.regex(/[A-Z]/, 'upper'),
  v.regex(/[a-z]/, 'lower'),
  v.regex(/[0-9]/, 'number'),
  v.regex(/[^A-Za-z0-9]/, 'special')
);

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
    required
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
    @validate={{(makePasswordValidator @linkedField)}}
    required
    autocomplete="new-password"
    ...attributes
  />
</template>;
