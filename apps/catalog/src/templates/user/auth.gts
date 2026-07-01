import { fn } from '@ember/helper';

import { ApiError, Apple, Github, Google } from '@sportipedia/ui';
import { PasswordField, PasswordValidateField } from '@sportipedia/user';
import { Await } from '@warp-drive/ember';
import { t } from 'ember-intl';
import { resource, resourceFactory } from 'ember-resources';

import { auth } from '#auth/client';
import { AccountsResource } from '#/domain/user/accounts';
import PhPassword from '~icons/ph/password';

import { Alert, Form, Page } from '@hokulea/ember';

import { BoxList } from './-box.gts';

const accountsResource = resourceFactory(() => resource(() => new AccountsResource()));

function getError() {
  const params = new URLSearchParams(globalThis.location.search);

  return params.get('error');
}

const changePassword = async ({
  currentPassword,
  newPassword
}: {
  currentPassword: string;
  newPassword: string;
}) => {
  const { error } = await auth.changePassword({ currentPassword, newPassword });

  if (error) {
    return {
      value: {},
      success: false,
      issues: [
        {
          message: error.message as string
        }
      ]
    };
  }
};

<template>
  <style scoped>
    .provider {
      div {
        background-color: var(--surface-container);
        border-inline: var(--shape-stroke);
        border-block-start: var(--shape-stroke);
        padding: var(--spacing-container0);

        &:first-child {
          border-start-start-radius: var(--shape-radius-container);
          border-start-end-radius: var(--shape-radius-container);
        }

        &:last-child {
          border-block-end: var(--shape-stroke);
          border-end-start-radius: var(--shape-radius-container);
          border-end-end-radius: var(--shape-radius-container);
        }
      }
    }

    .social {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
  </style>
  <Page @title={{t "user.pages.auth.title"}}>
    {{#let (getError) as |error|}}
      {{#if error}}
        <Alert @indicator="error" @title={{t "user.pages.auth.errors.title" error=error}}>
          {{t "user.pages.auth.errors.message" error=error}}
        </Alert>
      {{/if}}
    {{/let}}

    {{#let (accountsResource) as |accounts|}}
      <Await @promise={{(accounts.load)}}>
        <:pending>
          {{! <Spinner /> }}
        </:pending>

        <:error as |error|>
          <ApiError @error={{error}} />
        </:error>

        <:success>
          <BoxList as |Item|>
            <Item
              @icon={{PhPassword}}
              @openLabel={{t "user.pages.auth.actions.change-password"}}
              @closeLabel={{t "user.pages.auth.actions.hide"}}
            >
              <:content>
                {{t "user.pages.auth.password.title"}}
                <br /><small>
                  {{#if (accounts.usesProvider "credential")}}
                    {{t "user.pages.auth.password.set"}}
                  {{else}}
                    {{t "user.pages.auth.password.unset"}}
                  {{/if}}
                </small>
              </:content>
              <:disclosure>
                {{#if (accounts.usesProvider "credential")}}
                  <Form @submit={{changePassword}} as |f|>
                    <f.Errors />
                    <f.Password @name="currentPassword" @label="Current Password" />
                    <PasswordField @form={{f}} @name="newPassword" />
                    <PasswordValidateField
                      @form={{f}}
                      @name="newPassword_confirm"
                      @linkedField="newPassword"
                    />
                    <p><f.Submit>{{t "user.pages.auth.actions.change-password"}}</f.Submit></p>
                  </Form>
                {{else}}
                  TODO: Set yourself a password, when initially logged in through social provider
                {{/if}}
              </:disclosure>
            </Item>
            <Item @icon={{Github}}>
              <:content>
                Github<br />
                <small>{{t "user.components.login.actions.login-with" provider="github"}}</small>
              </:content>
              <:actions as |Action|>
                {{#if (accounts.usesProvider "github")}}
                  <Action @push={{fn accounts.unlinkSocial "github"}} @spacing="-1">
                    {{t "user.pages.auth.actions.unlink"}}
                  </Action>
                {{else}}
                  <Action @push={{fn accounts.linkSocial "github"}} @spacing="-1">
                    {{t "user.pages.auth.actions.link"}}
                  </Action>
                {{/if}}
              </:actions>
            </Item>

            <Item @icon={{Google}}>
              <:content>
                Google<br />
                <small>{{t "user.components.login.actions.login-with" provider="google"}}</small>
              </:content>
              <:actions as |Action|>
                {{#if (accounts.usesProvider "google")}}
                  <Action @push={{fn accounts.unlinkSocial "google"}} @spacing="-1">
                    {{t "user.pages.auth.actions.unlink"}}
                  </Action>
                {{else}}
                  <Action @push={{fn accounts.linkSocial "google"}} @spacing="-1">
                    {{t "user.pages.auth.actions.link"}}
                  </Action>
                {{/if}}
              </:actions>
            </Item>

            <Item @icon={{Apple}}>
              <:content>
                Apple<br />
                <small>{{t "user.components.login.actions.login-with" provider="apple"}}</small>
              </:content>
              <:actions as |Action|>
                {{#if (accounts.usesProvider "apple")}}
                  <Action @push={{fn accounts.unlinkSocial "apple"}} @spacing="-1">
                    {{t "user.pages.auth.actions.unlink"}}
                  </Action>
                {{else}}
                  <Action @push={{fn accounts.linkSocial "apple"}} @spacing="-1">
                    {{t "user.pages.auth.actions.link"}}
                  </Action>
                {{/if}}
              </:actions>
            </Item>
          </BoxList>
        </:success>
      </Await>
    {{/let}}
  </Page>
</template>
