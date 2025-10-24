import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

import { Await } from '@warp-drive/ember';

import { Avatar, DataTable, Link, Page } from '@hokulea/ember';

import { auth } from '../../../auth.ts';

import type { User } from '@sportipedia/user/domain/user';

const header = [
  { name: 'name', content: 'Name' },
  { name: 'email', content: 'Email' }
];

function mapRows(users: User[]): User[] {
  return users.map((user) => ({
    ...user,
    name: <template>
      <Avatar @src={{user.image}} @name={{user.name}} />
      <Link @href="/users/{{user.id}}">{{user.name}}</Link>
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
      <Await @promise={{this.request}}>
        <:success as |result|>
          <DataTable @header={{header}} @rows={{mapRows result.data.users}} />
        </:success>
      </Await>
    </Page>
  </template>
}
