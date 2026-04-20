import Component from '@glimmer/component';
import { service } from '@ember/service';

import { Button, Page } from '@hokulea/ember';

import type Store from '#/services/store';

export default class PingPage extends Component {
  @service declare store: Store;

  ping = async () => {
    const result = await this.store.request({
      url: `${__API_URL__}/catalog/ping`,
      method: 'POST'
    });

    console.log('ping result', result);
  };

  <template>
    <Page @title="Ping">
      <p>tetete</p>
      <Button @push={{this.ping}}>Ping</Button>
    </Page>
  </template>
}
