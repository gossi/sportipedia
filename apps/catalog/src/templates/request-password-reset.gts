import { t } from 'ember-intl';

import { auth } from '#/auth';

import { FocusPage, Form } from '@hokulea/ember';

async function requestPasswordReset({ email }: { email: string }) {
  await auth.requestPasswordReset({
    email,
    redirectTo: 'http://localhost:4101/reset-password'
  });
}

<template>
  <FocusPage @title={{t "user.pages.request-password-reset.title"}}>
    <Form @submit={{requestPasswordReset}} as |f|>
      <f.Email @name="email" @label="Email" />

      <p><f.Submit>request PW</f.Submit></p>
    </Form>
  </FocusPage>
</template>
