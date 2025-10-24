import { RegistrationForm } from '@sportipedia/user';
import { t } from 'ember-intl';

import { Page } from '@hokulea/ember';

// import type { SessionService } from 'ember-auth';

<template>
  <Page class="registration">
    <h1>{{t "user.pages.registration.heading"}}</h1>

    <div>
      <RegistrationForm />
    </div>

  </Page>
</template>
