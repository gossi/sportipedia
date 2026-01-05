import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { fn } from '@ember/helper';

import { Await } from '@warp-drive/ember';
import { resource, resourceFactory } from 'ember-resources';

import PhCheck from '~icons/ph/check';
import PhX from '~icons/ph/x';

import { Avatar, Card, Form, Icon, Page, Section } from '@hokulea/ember';

import { auth } from '../../../auth.ts';
import { UserResource } from './resource.ts';

import type { TOC } from '@ember/component/template-only';

interface TagSignature {
  Element: HTMLElement;
  Blocks: {
    default: [];
  };
}

const Tag: TOC<TagSignature> = <template>
  <style>
    .tag {
      padding: 0.25em;

      font-size: 80%;
      font-weight: 500;
      color: var(--typography-code-text);
      white-space: nowrap;

      background-color: hsl(from var(--typography-code-background) h s calc(l - 3));
      border-radius: 4px;
    }
  </style>
  <span class="tag" ...attributes>{{yield}}</span>
</template>;

const userResource = resourceFactory((userId: string) => resource(() => new UserResource(userId)));

interface Signature {
  Args: {
    model: {
      id: string;
    };
  };
}

export default class UserDetailsPage extends Component<Signature> {
  @tracked query: Parameters<typeof auth.admin.listUsers>[0]['query'] = {
    sortBy: 'createdAt',
    sortDirection: 'desc'
  };

  get request() {
    return auth.admin.listUsers({
      query: {
        filterField: 'id',
        filterValue: this.args.model.id
      }
    });
  }

  <template>
    {{#let (userResource @model.id) as |ur|}}
      <Await @promise={{(ur.load)}}>
        <:success>
          {{#let ur.user as |user|}}
            <Page>
              <:title>
                <Avatar @src={{user.image}} @name={{user.name}} />
                {{user.name}}
              </:title>
              <:content>
                <p>
                  <Tag>{{user.role}}</Tag>
                  -
                  {{user.email}}
                  {{#if user.emailVerified}}
                    <Icon @icon={{PhCheck}} />
                    <small>(verified)</small>
                  {{else}}
                    <Icon @icon={{PhX}} />
                    <small>(non-verified)</small>
                  {{/if}}

                </p>

                <Section @title="Name">
                  <Card>
                    <Form @data={{user}} @submit={{fn ur.changeName user.id}} as |f|>
                      <f.Text @name="givenName" @label="Given Name" />
                      <f.Text @name="familyName" @label="Family Name" />

                      <p><f.Submit>Change Name</f.Submit></p>
                    </Form>
                  </Card>
                </Section>

                <Section @title="Email">
                  <Card>
                    <Form @data={{user}} @submit={{fn ur.changeEmail user.id}} as |f|>
                      <f.Text @name="email" @label="Email" />

                      <p><f.Submit>Change Email</f.Submit></p>
                    </Form>
                  </Card>
                </Section>
              </:content>
            </Page>
          {{/let}}
        </:success>
      </Await>
    {{/let}}
  </template>
}
