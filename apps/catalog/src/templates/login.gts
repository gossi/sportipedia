import { LoginForm } from '@sportipedia/user';
import { t } from 'ember-intl';
import { link } from 'ember-link';

import { FocusPage } from '@hokulea/ember';

<template>
  <FocusPage @title={{t "user.pages.login.heading"}}>
    <LoginForm
      @registrationLink={{link "registration"}}
      @resetPasswordLink={{link "request-password-reset"}}
      @callbackURL="http://localhost:4101"
    />
  </FocusPage>
</template>
