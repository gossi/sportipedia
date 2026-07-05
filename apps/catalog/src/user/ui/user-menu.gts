import { getUser, isAuthenticated } from '@sportipedia/user';
import { t } from 'ember-intl';

import BroadcastIcon from '~icons/ph/broadcast';
import GearIcon from '~icons/ph/gear';
import KeyIcon from '~icons/ph/key';
import PaintBrushIcon from '~icons/ph/paint-brush';
import SignOutIcon from '~icons/ph/sign-out';

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
            <Icon @icon={{GearIcon}} />
            {{t "user.ui.user-menu.settings"}}
          </um.Item>
          <um.Item @href="/user/appearance">
            <Icon @icon={{PaintBrushIcon}} />
            {{t "user.pages.appearance.title"}}
          </um.Item>
          <um.Item @href="/user/sessions">
            <Icon @icon={{BroadcastIcon}} />
            {{t "user.pages.sessions.title"}}
          </um.Item>
          <um.Item @href="/user/auth">
            <Icon @icon={{KeyIcon}} />
            {{t "user.pages.auth.title"}}
          </um.Item>
          <hr />
          <um.Item @href="/logout">
            <Icon @icon={{SignOutIcon}} />
            {{t "user.ui.user-menu.logout"}}
          </um.Item>
        </:menu>
      </@nav.Item>
    {{/let}}
  {{else}}
    <@nav.Item @href="/login">Login</@nav.Item>
  {{/if}}
</template>;

export { UserMenu };
