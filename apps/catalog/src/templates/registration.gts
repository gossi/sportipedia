import { RegistrationForm } from '@sportipedia/user';
import { t } from 'ember-intl';

import { FocusPage } from '@hokulea/ember';

<template>
  <FocusPage @title={{t "user.pages.registration.heading"}}>
    <RegistrationForm />
  </FocusPage>
</template>
