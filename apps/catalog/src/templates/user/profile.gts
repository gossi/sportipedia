import { getUser } from '@sportipedia/user';
import { t } from 'ember-intl';

import { auth } from '#auth/client';

import { Card, Form, Page, Section, type SubmitHandler } from '@hokulea/ember';

import type { User } from '@sportipedia/user';

const changeName = async (data: User) => {
  const { error } = await auth.updateUser({
    // @ts-expect-error better-auth doesn't work with custom fields
    givenName: data.givenName,
    familyName: data.familyName,
    name: `${data.givenName} ${data.familyName}`
  });

  if (error) {
    return {
      value: data,
      success: false,
      issues: [
        {
          message: error.message as string
        }
      ]
    };
  }
};

const changeEmail: SubmitHandler = async (
  { email }: { email: string },
  callbackURL = 'http://localhost:4101/user/profile'
) => {
  const { error } = await auth.changeEmail({ newEmail: email, callbackURL });

  if (error) {
    return {
      value: { email },
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
  <Page @title={{t "user.pages.profile.title"}}>
    <Section @title={{t "user.pages.profile.sections.name"}}>
      <Card>
        {{#let (getUser) as |user|}}
          <Form @data={{user}} @submit={{changeName}} as |f|>
            <f.Errors />
            <f.Text @name="givenName" @label={{t "user.labels.given-name"}} />
            <f.Text @name="familyName" @label={{t "user.labels.family-name"}} />

            <p><f.Submit>{{t "user.pages.profile.actions.change-name"}}</f.Submit></p>
          </Form>
        {{/let}}
      </Card>
    </Section>

    <Section @title={{t "user.pages.profile.sections.email"}}>
      <Card>
        {{#let (getUser) as |user|}}
          <Form @data={{user}} @submit={{changeEmail}} as |f|>
            <f.Errors />
            <f.Email @name="email" @label={{t "user.labels.email"}} />

            <p><f.Submit>{{t "user.pages.profile.actions.change-email"}}</f.Submit></p>
          </Form>
        {{/let}}
      </Card>
    </Section>
  </Page>
</template>
