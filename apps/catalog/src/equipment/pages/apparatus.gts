import Component from '@glimmer/component';
import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { ApiError, Loading } from '@sportipedia/ui';
import { Request } from '@warp-drive/ember';
import { ability } from 'ember-ability';

import {
  canArchiveApparatus as upstreamCanArchiveApparatus,
  canEditApparatus as upstreamCanEditApparatus
} from '../domain-objects/apparatus/abilities';
import { archiveApparatus } from '../domain-objects/apparatus/actions';
import { readApparatus } from '../domain-objects/apparatus/queries';
import { asReactiveApparatusResource } from '../domain-objects/equipment';
import { EquipmentDetail } from '../ui/equipment-detail.gts';

import type { Apparatus } from '../domain-objects/apparatus/apparatus';
import type RouterService from '@ember/routing/router-service';
import type { ReactiveResource } from '@warp-drive/core/reactive';
import type { Store } from '#support/data';

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
      apparatus
    };
  }
}

class ApparatusTemplate extends Component<{
  Args: { model: { apparatus: string } };
}> {
  @service declare store: Store;
  @service declare router: RouterService;

  get request() {
    return this.store.request(readApparatus(this.args.model.apparatus));
  }

  archive = async (record: Apparatus & ReactiveResource) => {
    try {
      await this.store.request(archiveApparatus(record, { store: this.store }));

      this.router.transitionTo('equipment');
    } catch (error) {
      console.log('error', error);
    }
  };

  <template>
    <Request @request={{this.request}}>
      <:loading>
        <Loading />
      </:loading>

      <:error as |error|>
        <ApiError @error={{error}} />
      </:error>

      <:content as |result|>
        <EquipmentDetail
          @equipment={{result.data}}
          @editingAllowed={{canEditApparatus result.data}}
          @archivingAllowed={{canArchiveApparatus result.data}}
          @editHref="/equipment/apparatus/{{result.data.slug}}/edit"
          @archive={{fn this.archive (asReactiveApparatusResource result.data)}}
        />
      </:content>
    </Request>
  </template>
}
export { ApparatusRoute, ApparatusTemplate };
