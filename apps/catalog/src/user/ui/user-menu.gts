import { getUser, isAuthenticated } from '@sportipedia/user';
import { t } from 'ember-intl';

import PhBroadcast from '~icons/ph/broadcast';
import PhGear from '~icons/ph/gear';
import PhKey from '~icons/ph/key';
import PhSignOut from '~icons/ph/sign-out';

// import PhUser from '~icons/ph/user';
import { Avatar, Icon, type MenuBuilder } from '@hokulea/ember';

import type { TOC } from '@ember/component/template-only';

interface UserMenuSignature {
  Args: {
    nav: MenuBuilder;
  };
}

const UserMenu: TOC<UserMenuSignature> = <template>
  {{#if (isAuthenticated)}}
    {{#let (getUser) as |user|}}
      <@nav.Item>
        <:label>
          <Avatar @src={{user.image}} @name={{user.name}} />
        </:label>
        <:menu as |um|>
          <um.Item @href="/user/profile">
            <Icon @icon={{PhGear}} />
            {{t "user.components.user-menu.settings"}}
          </um.Item>
          <um.Item @href="/user/sessions">
            <Icon @icon={{PhBroadcast}} />
            {{t "user.pages.sessions.title"}}
          </um.Item>
          <um.Item @href="/user/auth">
            <Icon @icon={{PhKey}} />
            {{t "user.pages.auth.title"}}
          </um.Item>
          <hr />
          <um.Item @href="/logout">
            <Icon @icon={{PhSignOut}} />
            {{t "user.components.user-menu.logout"}}
          </um.Item>
        </:menu>
      </@nav.Item>
    {{/let}}
  {{else}}
    <@nav.Item @href="/login">Login</@nav.Item>
  {{/if}}
</template>;

export { UserMenu };
