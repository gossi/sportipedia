import Component from '@glimmer/component';
import { service } from '@ember/service';

import { type IntlService, t } from 'ember-intl';

import { withValidation } from '#support/data/validation.ts';

import { Page } from '@hokulea/ember';

import { catalogApparatus } from '../domain-objects/apparatus/actions';
import { EquipmentForm } from '../ui/equipment-form.gts';

import type { Apparatus } from '../domain-objects/apparatus/apparatus';
import type { Equipment } from '../domain-objects/equipment';
import type RouterService from '@ember/routing/router-service';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type { Store } from '#support/data';;

export class CatalogApparatusTemplate extends Component {
  @service declare store: Store;
  @service declare intl: IntlService;
  @service declare router: RouterService;

  submit = async (data: Equipment) => {
    return withValidation(
      async () => {
        const result = await this.store.request<ReactiveDataDocument<Apparatus>>({
          ...catalogApparatus(data as Apparatus, { store: this.store }),
          cacheOptions: {
            types: ['apparatuses']
          }
        });

        this.router.transitionTo('equipment.apparatus', result.content.data.slug);
      },
      {
        namespace: 'equipment.ui.equipment-form.errors',
        intl: this.intl
      }
    );
  };

  <template>
    <Page
      @title={{t "equipment.pages.catalog-apparatus.title"}}
      @description={{t "equipment.basic.apparatus.explanation"}}
    >
      <EquipmentForm @submit={{this.submit}} />
    </Page>
  </template>
}
