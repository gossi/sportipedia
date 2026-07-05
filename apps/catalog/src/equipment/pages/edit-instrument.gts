import Component from '@glimmer/component';
import Route from '@ember/routing/route';
import { service } from '@ember/service';

import {
  checkout,
  type ReactiveDataDocument,
  type ReactiveResource
} from '@warp-drive/core/reactive';
import { Request } from '@warp-drive/ember';
import { type IntlService, t } from 'ember-intl';

import { withValidation } from '#support/data/validation.ts';

import { Page } from '@hokulea/ember';

import { editInstrument } from '../domain-objects/instrument/actions';
import { EquipmentForm } from '../ui/equipment-form.gts';

import type { Equipment } from '../domain-objects/equipment';
import type { Instrument } from '../domain-objects/instrument/instrument';
import type RouterService from '@ember/routing/router-service';
import type { Future } from '@warp-drive/core/request';
import type { Store } from '#support/data';

function asReactiveResource(record: Instrument): ReactiveResource & Instrument {
  return record as ReactiveResource & Instrument;
}

class EditInstrumentRoute extends Route {
  @service declare store: Store;

  model() {
    return this.modelFor('equipment.instrument');
  }
}

class EditInstrumentTemplate extends Component<{
  Args: { model: { request: Future<ReactiveDataDocument<Instrument>> } };
}> {
  @service declare store: Store;
  @service declare router: RouterService;
  @service declare intl: IntlService;

  submit = async (record: Instrument & ReactiveResource, changes: Equipment) => {
    return withValidation(
      async () => {
        const result = await this.store.request<ReactiveDataDocument<Instrument>>({
          ...editInstrument(await checkout(record), changes as Instrument, { store: this.store }),
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
      @title={{t "equipment.pages.edit-instrument.title"}}
      @description={{t "equipment.basic.instrument.explanation"}}
    >
      <Request @request={{@model.request}}>
        <:content as |result|>
          <EquipmentForm
            @equipment={{result.data}}
            @submit={{fn this.submit (asReactiveResource result.data)}}
          />
        </:content>
      </Request>
    </Page>
  </template>
}

export { EditInstrumentRoute, EditInstrumentTemplate };
