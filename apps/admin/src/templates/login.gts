import { LoginForm } from '@sportipedia/user';
import { t } from 'ember-intl';
import { link } from 'ember-link';

import { FocusPage } from '@hokulea/ember';

<template>
  <FocusPage @title={{t "accounts.pages.login.heading"}}>
    <LoginForm @registrationLink={{link "registration"}} @callbackURL="http://localhost:4200" />
  </FocusPage>
</template>
