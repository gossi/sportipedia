import Component from '@glimmer/component';
import { service } from '@ember/service';

import { type IntlService, t } from 'ember-intl';

import { withValidation } from '#support/data/validation.ts';

import { Page } from '@hokulea/ember';

import { catalogInstrument } from '../domain-objects/instrument/actions';
import { EquipmentForm } from '../ui/equipment-form.gts';

import type { Equipment } from '../domain-objects/equipment';
import type { Instrument } from '../domain-objects/instrument/instrument';
import type RouterService from '@ember/routing/router-service';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type Store from '#/services/store';

export class CatalogInstrumentTemplate extends Component {
  @service declare store: Store;
  @service declare intl: IntlService;
  @service declare router: RouterService;

  submit = async (data: Equipment) => {
    return withValidation(
      async () => {
        const result = await this.store.request<ReactiveDataDocument<Instrument>>({
          ...catalogInstrument(data as Instrument, { store: this.store }),
          cacheOptions: {
            types: ['instruments']
          }
        });

        this.router.transitionTo('equipment.instrument', result.content.data.slug);
      },
      {
        namespace: 'equipment.ui.equipment-form.errors',
        intl: this.intl
      }
    );
  };

  <template>
    <Page
      @title={{t "equipment.pages.catalog-instrument.title"}}
      @description={{t "equipment.basic.instrument.explanation"}}
    >
      <EquipmentForm @submit={{this.submit}} />
    </Page>
  </template>
}
