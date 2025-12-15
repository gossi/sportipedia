import { getUser } from '@sportipedia/user';
import { t } from 'ember-intl';

import PhBroadcast from '~icons/ph/broadcast';
import PhKey from '~icons/ph/key';
import PhUser from '~icons/ph/user';

import { Avatar, NavigationList, Page } from '@hokulea/ember';

<template>
  <style>
    .user h1 {
      display: flex;
      align-items: center;
      gap: var(--s-1);
    }
    .navigation {
      display: grid;
      grid-template-columns: 30% auto;
      gap: var(--spacing-container0);
    }
  </style>
  <Page class="user">
    <:title>
      {{#let (getUser) as |user|}}
        <Avatar @src={{user.image}} @name={{user.name}} />
        {{user.name}}
      {{/let}}
    </:title>
    <:content>
      <div class="navigation">
        <NavigationList as |n|>
          <n.Item @href="/user/profile" @icon={{PhUser}}>{{t "user.pages.profile.title"}}</n.Item>
          <n.Item @href="/user/sessions" @icon={{PhBroadcast}}>{{t
              "user.pages.sessions.title"
            }}</n.Item>
          <n.Item @href="/user/auth" @icon={{PhKey}}>{{t "user.pages.auth.title"}}</n.Item>
        </NavigationList>
        {{outlet}}
      </div>
    </:content>
  </Page>
</template>
