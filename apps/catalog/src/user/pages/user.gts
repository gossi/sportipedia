import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { getUser } from '@sportipedia/user';
import { t } from 'ember-intl';

import BroadcastIcon from '~icons/ph/broadcast';
import KeyIcon from '~icons/ph/key';
import PaintBrushIcon from '~icons/ph/paint-brush';
import UserIcon from '~icons/ph/user';

import { Avatar, NavigationList, Page } from '@hokulea/ember';

import type Transition from '@ember/routing/transition';
import type { AuthService } from '@sportipedia/user';

class UserRoute extends Route {
  @service declare auth: AuthService;

  async beforeModel(transition: Transition) {
    const authenticated = await this.auth.requireAuthentication(transition);

    if (!authenticated) {
      this._router.transitionTo('login');
    }
  }
}

const UserTemplate = <template>
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
          <n.Item @href="/user/profile" @icon={{UserIcon}}>{{t "user.pages.profile.title"}}</n.Item>
          <n.Item @href="/user/appearance" @icon={{PaintBrushIcon}}>{{t
              "user.pages.appearance.title"
            }}</n.Item>
          <n.Item @href="/user/sessions" @icon={{BroadcastIcon}}>{{t
              "user.pages.sessions.title"
            }}</n.Item>
          <n.Item @href="/user/auth" @icon={{KeyIcon}}>{{t "user.pages.auth.title"}}</n.Item>
        </NavigationList>
        {{outlet}}
      </div>
    </:content>
  </Page>
</template>;

export { UserRoute, UserTemplate };
