import { ResetPasswordPage } from '@sportipedia/user';
import { link } from 'ember-link';

import { auth } from '#auth/client';

<template>
  <ResetPasswordPage
    @auth={{auth}}
    @requestPasswordResetLink={{link "/request-password-reset"}}
    @loginLink={{link "/login"}}
  />
</template>
