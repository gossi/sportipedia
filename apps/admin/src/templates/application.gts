import { getUser, isAdmin } from '@sportipedia/user';
import { link } from 'ember-link';
import { pageTitle } from 'ember-page-title';

// import UserMenu from '#/components/user-menu.gts';
import { AppHeader, Avatar } from '@hokulea/ember';

<template>
  <style>
    .avatar:has(img) {
      font-size: var(--s1);
    }
  </style>
  {{pageTitle "Sportipedia"}}

  {{#let (getUser) as |user|}}
    {{#if (isAdmin user)}}
      <AppHeader @home={{link "application"}}>
        <:brand>Sportipedia ADM</:brand>
        <:nav as |n|>
          <n.Item @push={{link "protected.users"}}>Users</n.Item>
        </:nav>
        <:aux as |n|>
          <n.Item>
            <:label>
              <Avatar @src={{user.image}} @name={{user.name}} class="avatar" />
            </:label>
            <:menu as |um|>
              <um.Item @push={{link "logout"}}>Logout</um.Item>
            </:menu>
          </n.Item>
        </:aux>
      </AppHeader>
    {{/if}}
  {{/let}}

  {{outlet}}
</template>
