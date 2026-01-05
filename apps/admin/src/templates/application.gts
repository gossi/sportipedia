import { getUser, isAdmin } from '@sportipedia/user';
import { link } from 'ember-link';
import { pageTitle } from 'ember-page-title';

import { AppHeader, Avatar } from '@hokulea/ember';

<template>
  {{pageTitle "Sportipedia"}}

  {{#let (getUser) as |user|}}
    {{#if user}}
      {{#if (isAdmin user)}}
        <AppHeader @home={{link "application"}}>
          <:brand>Sportipedia ADM</:brand>
          <:nav as |n|>
            <n.Item @href="/users">Users</n.Item>
          </:nav>
          <:aux as |n|>
            <n.Item>
              <:label>
                <Avatar @src={{user.image}} @name={{user.name}} class="avatar" />
              </:label>
              <:menu as |um|>
                <um.Item @href="/logout">Logout</um.Item>
              </:menu>
            </n.Item>
          </:aux>
        </AppHeader>
      {{/if}}
    {{/if}}
  {{/let}}

  {{outlet}}
</template>
