import { getUser } from '@sportipedia/user';
import { t } from 'ember-intl';

import { auth } from '#/auth';

import { Card, Form, Page, Section } from '@hokulea/ember';

import type { User } from '@sportipedia/user';

const changeName = async (data: User) => {
  await auth.updateUser({
    givenName: data.givenName,
    familyName: data.familyName,
    name: `${data.givenName} ${data.familyName}`
  });
};

<template>
  <Page @title={{t "user.pages.profile.title"}}>
    <Section @title="Name">
      <Card>
        {{#let (getUser) as |user|}}
          <Form @data={{user}} @submit={{changeName}} as |f|>
            <f.Text @name="givenName" @label="Given Name" />
            <f.Text @name="familyName" @label="Family Name" />

            <p><f.Submit>Change Name</f.Submit></p>
          </Form>
        {{/let}}
      </Card>
    </Section>
  </Page>
</template>
