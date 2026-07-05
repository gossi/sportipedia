import { t } from 'ember-intl';
import { link } from 'ember-link';
import { pageTitle } from 'ember-page-title';

import { UserMenu } from '#user';

import { AppHeader } from '@hokulea/ember';
import { LocaleSwitcher } from './components/locale-switcher.gts';

const ApplicationTemplate = <template>
  {{pageTitle "Sportipedia"}}

  <AppHeader @home={{link "application"}}>
    <:brand>Sportipedia</:brand>
    <:nav as |n|>
      hi
      <n.Item @href="/equipment" class="nav-push">{{t "app.header.nav.manage.equipment"}}</n.Item>
    </:nav>
    <:aux as |n|>
      <n.Item>
        <:label>{{t "app.header.nav.manage.label"}}</:label>
        <:menu as |m|>
          <m.Item @href="/equipment">{{t "app.header.nav.manage.equipment"}}</m.Item>
        </:menu>
      </n.Item>

      {{! @glint-expect-error see: https://github.com/hokulea/hokulea/issues/548 }}
      <LocaleSwitcher @nav={{n}} />
      {{! @glint-expect-error see: https://github.com/hokulea/hokulea/issues/548 }}
      <UserMenu @nav={{n}} />
    </:aux>
  </AppHeader>

  {{outlet}}
</template>;

export { ApplicationTemplate };
