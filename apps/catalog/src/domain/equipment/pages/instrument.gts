import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { Request } from '@warp-drive/ember';
import { ability } from 'ember-ability';

import {
  canArchiveInstrument as upstreamCanArchiveInstrument,
  canEditInstrument as upstreamCanEditInstrument
} from '../domain-objects/instrument/abilities';
import { readInstrument } from '../domain-objects/instrument/queries';
import { EquipmentDetail } from '../ui/equipment-detail.gts';

import type { Instrument } from '../domain-objects/instrument/instrument';
import type { TOC } from '@ember/component/template-only';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type { Future } from '@warp-drive/core/request';
import type Store from '#/services/store';

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
      request: this.store.request(readInstrument(instrument))
    };
  }
}

const InstrumentTemplate: TOC<{
  Args: { model: { request: Future<ReactiveDataDocument<Instrument>> } };
}> = <template>
  <Request @request={{@model.request}}>
    <:content as |result|>
      <EquipmentDetail
        @equipment={{result.data}}
        @editingAllowed={{canEditInstrument result.data}}
        @archivingAllowed={{canArchiveInstrument result.data}}
        @editHref="/equipment/instrument/{{result.data.slug}}/edit"
      />
    </:content>
  </Request>
</template>;

export { InstrumentRoute, InstrumentTemplate };
