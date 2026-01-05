import { LoginForm } from '@sportipedia/user';
import { t } from 'ember-intl';

import { FocusPage } from '@hokulea/ember';

<template>
  <FocusPage @title={{t "accounts.pages.login.heading"}}>
    <LoginForm @callbackURL="http://localhost:4100" />
  </FocusPage>
</template>
