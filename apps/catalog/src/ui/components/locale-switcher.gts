import Component from '@glimmer/component';
import { service } from '@ember/service';

import { changeLocale, renderLocale } from '#user';
import TranslateIcon from '~icons/ph/translate';

import { Icon, type MenuBuilder } from '@hokulea/ember';

import type { AuthService } from '@sportipedia/user';
import type { IntlService } from 'ember-intl';

interface LocaleSwitcherSignature {
  Args: {
    nav: MenuBuilder;
  };
}

export class LocaleSwitcher extends Component<LocaleSwitcherSignature> {
  @service declare intl: IntlService;
  @service declare auth: AuthService;

  switch = async (locale: string) => {
    try {
      await changeLocale(locale, { intl: this.intl });
    } catch {
      // trying is enough
    }
  };

  <template>
    <@nav.Item>
      <:label>
        <Icon @icon={{TranslateIcon}} />
      </:label>
      <:menu as |um|>
        {{#each this.intl.locales as |locale|}}
          <um.Item @push={{fn this.switch locale}}>
            {{renderLocale locale}}
          </um.Item>
        {{/each}}
      </:menu>
    </@nav.Item>
  </template>
}
