import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { fn } from '@ember/helper';

import { getUser, type User } from '@sportipedia/user';
import { Await } from '@warp-drive/ember';
import { notEq } from 'ember-truth-helpers';

import { auth } from '#/auth.ts';
import PhCheck from '~icons/ph/check';
import PhX from '~icons/ph/x';

import { Avatar, DataTable, Icon, Link, Page } from '@hokulea/ember';

// async function backdoor(user: User) {
//   await auth.admin.impersonateUser({
//     userId: user.id
//   });
// }

const header = [
  { name: 'name', content: 'Name' },
  { name: 'email', content: 'Email' },
  { name: 'actions', content: 'Actions' }
];

function mapRows(users: User[], me: User) {
  return users.map((user) => ({
    email: <template>
      <Icon @icon={{if user.emailVerified PhCheck PhX}} />
      {{user.email}}
    </template>,
    name: <template>
      <Avatar @src={{user.image}} @name={{user.name}} />
      <Link @href="/users/{{user.id}}">{{user.name}}</Link>
    </template>,
    actions: <template>
      {{#if (notEq user.id me.id)}}
        backdoor
        {{!-- <Button @push={{fn backdoor user}} @spacing="-1" @importance="subtle">Backdoor</Button> --}}
      {{/if}}
    </template>
  }));
}

export default class UsersPage extends Component {
  @tracked query: Parameters<typeof auth.admin.listUsers>[0]['query'] = {
    sortBy: 'createdAt',
    sortDirection: 'desc'
  };

  get request() {
    return auth.admin.listUsers({ query: this.query });
  }

  <template>
    <Page @title="Users">
      {{#let (getUser) as |me|}}
        <Await @promise={{this.request}}>
          <:success as |result|>
            <DataTable @header={{header}} @rows={{mapRows result.data.users me}} />
          </:success>
        </Await>
      {{/let}}
    </Page>
  </template>
}
