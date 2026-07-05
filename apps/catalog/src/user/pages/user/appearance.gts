import Component from '@glimmer/component';
import { service } from '@ember/service';

import { getUser } from '@sportipedia/user';
import { type IntlService, t } from 'ember-intl';

import { Form, Page, Section, type SubmitHandler } from '@hokulea/ember';

import { changeLocale, renderLocale } from '../../domain-objects/language';

class ApperanceTemplate extends Component {
  @service declare intl: IntlService;

  changeLanguage: SubmitHandler = async ({ lang }: { lang: string }) => {
    const { error } = await changeLocale(lang, { intl: this.intl });

    if (error) {
      return {
        value: { lang },
        success: false,
        issues: [
          {
            message: error.message as string
          }
        ]
      };
    }
  };

  <template>
    <Page @title={{t "user.pages.appearance.title"}}>
      <Section @title={{t "user.pages.appearance.sections.language"}}>

        {{#let (getUser) as |user|}}
          <Form @data={{user}} @submit={{this.changeLanguage}} as |f|>
            <f.Errors />

            <f.Select @name="lang" @label={{t "user.labels.language"}} as |s|>
              {{#each this.intl.locales as |locale|}}
                <s.Option @value={{locale}}>
                  {{renderLocale locale}}
                </s.Option>
              {{/each}}
            </f.Select>

            <p><f.Submit>{{t "user.pages.appearance.actions.change-language"}}</f.Submit></p>
          </Form>
        {{/let}}

      </Section>
    </Page>
  </template>
}

export { ApperanceTemplate };
