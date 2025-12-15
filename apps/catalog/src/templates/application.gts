import { link } from 'ember-link';
import { pageTitle } from 'ember-page-title';

import { UserMenu } from '#/components/user-menu.gts';

// import UserMenu from '#/components/user-menu.gts';
import { AppHeader } from '@hokulea/ember';

<template>
  {{pageTitle "Sportipedia"}}

  <AppHeader @home={{link "application"}}>
    <:brand>Sportipedia</:brand>
    <:nav>
      hi
      {{!-- <n.Item @push={{link "blog"}}>Blog</n.Item> --}}
    </:nav>
    <:aux as |n|>
      {{!-- <n.Item @push={{link "login"}}>Login</n.Item> --}}
      <UserMenu @nav={{n}} />

    </:aux>
  </AppHeader>

  {{outlet}}
</template>
