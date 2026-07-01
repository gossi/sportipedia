import Component from '@glimmer/component';
import { service } from '@ember/service';

import { t } from 'ember-intl';

import { Page } from '@hokulea/ember';

import { catalogInstrument } from '../domain-objects/instrument/actions';
import { EquipmentForm } from '../ui/equipment-form.gts';

import type { Equipment } from '../domain-objects/equipment';
import type { Instrument } from '../domain-objects/instrument/instrument';
import type Store from '#/services/store';

export class CatalogInstrumentTemplate extends Component {
  @service declare store: Store;

  submit = async (data: Equipment) => {
    // log
    console.log(data);

    const result = await catalogInstrument(data as Instrument, { store: this.store });

    console.log('result', result);
  };

  <template>
    <Page @title={{t "equipment.pages.catalog-instrument.title"}}>
      <EquipmentForm @submit={{this.submit}} />
    </Page>
  </template>
}
