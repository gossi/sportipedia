import Component from '@glimmer/component';
import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { ApiError } from '@sportipedia/ui';
import { Request } from '@warp-drive/ember';
import { ability } from 'ember-ability';

import { asReactiveInstrumentResource } from '../domain-objects/equipment';
import {
  canArchiveInstrument as upstreamCanArchiveInstrument,
  canEditInstrument as upstreamCanEditInstrument
} from '../domain-objects/instrument/abilities';
import { archiveInstrument } from '../domain-objects/instrument/actions';
import { readInstrument } from '../domain-objects/instrument/queries';
import { EquipmentDetail } from '../ui/equipment-detail.gts';

import type { Instrument } from '../domain-objects/instrument/instrument';
import type RouterService from '@ember/routing/router-service';
import type { ReactiveResource } from '@warp-drive/core/reactive';
// import type { Future } from '@warp-drive/core/request';
import type { Store } from '#support/data';

const canEditInstrument = ability(
  ({ services }) =>
    (_instrument: Instrument) =>
      upstreamCanEditInstrument(_instrument, services.auth.user)
);

const canArchiveInstrument = ability(
  ({ services }) =>
    (_instrument: Instrument) =>
      upstreamCanArchiveInstrument(_instrument, services.auth.user)
);

class InstrumentRoute extends Route {
  @service declare store: Store;

  model({ instrument }: { instrument: string }) {
    return {
      instrument
      // request: this.store.request(readInstrument(instrument))
    };
  }
}

class InstrumentTemplate extends Component<{
  // Args: { model: { request: Future<ReactiveDataDocument<Instrument>> } };
  Args: { model: { instrument: string } };
}> {
  @service declare store: Store;
  @service declare router: RouterService;

  get request() {
    return this.store.request(readInstrument(this.args.model.instrument));
  }

  archive = async (record: Instrument & ReactiveResource) => {
    try {
      await this.store.request(archiveInstrument(record, { store: this.store }));

      this.router.transitionTo('equipment');
    } catch (error) {
      console.log('error', error);
    }
  };

  <template>
    <Request @request={{this.request}}>
      <:error as |error|>
        <ApiError @error={{error}} />
      </:error>

      <:content as |result|>
        <EquipmentDetail
          @equipment={{result.data}}
          @editingAllowed={{canEditInstrument result.data}}
          @archivingAllowed={{canArchiveInstrument result.data}}
          @editHref="/equipment/instrument/{{result.data.slug}}/edit"
          @archive={{fn this.archive (asReactiveInstrumentResource result.data)}}
        />
      </:content>
    </Request>
  </template>
}
export { InstrumentRoute, InstrumentTemplate };
