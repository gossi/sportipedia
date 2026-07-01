import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { Request } from '@warp-drive/ember';
import { ability } from 'ember-ability';

import {
  canArchiveApparatus as upstreamCanArchiveApparatus,
  canEditApparatus as upstreamCanEditApparatus
} from '../domain-objects/apparatus/abilities';
import { readApparatus } from '../domain-objects/apparatus/queries';
import { EquipmentDetail } from '../ui/equipment-detail.gts';

import type { Apparatus } from '../domain-objects/apparatus/apparatus';
import type { TOC } from '@ember/component/template-only';
import type { ReactiveDataDocument } from '@warp-drive/core/reactive';
import type { Future } from '@warp-drive/core/request';
import type Store from '#/services/store';

const canEditApparatus = ability(
  ({ services }) =>
    (_apparatus: Apparatus) =>
      upstreamCanEditApparatus(_apparatus, services.auth.user)
);

const canArchiveApparatus = ability(
  ({ services }) =>
    (_apparatus: Apparatus) =>
      upstreamCanArchiveApparatus(_apparatus, services.auth.user)
);

class ApparatusRoute extends Route {
  @service declare store: Store;

  model({ apparatus }: { apparatus: string }) {
    return {
      request: this.store.request(readApparatus(apparatus))
    };
  }
}

const ApparatusTemplate: TOC<{
  Args: { model: { request: Future<ReactiveDataDocument<Apparatus>> } };
}> = <template>
  <Request @request={{@model.request}}>
    <:content as |result|>
      <EquipmentDetail
        @equipment={{result.data}}
        @editingAllowed={{canEditApparatus result.data}}
        @archivingAllowed={{canArchiveApparatus result.data}}
        @editHref="/equipment/apparatus/{{result.data.slug}}/edit"
      />
    </:content>
  </Request>
</template>;

export { ApparatusRoute, ApparatusTemplate };
