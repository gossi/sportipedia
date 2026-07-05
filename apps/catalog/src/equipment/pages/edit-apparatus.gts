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

import { editApparatus } from '../domain-objects/apparatus/actions';
import { asReactiveApparatusResource, type Equipment } from '../domain-objects/equipment';
import { EquipmentForm } from '../ui/equipment-form.gts';

import type { Apparatus } from '../domain-objects/apparatus/apparatus';
import type RouterService from '@ember/routing/router-service';
import type { Future } from '@warp-drive/core/request';
import type { Store } from '#support/data';;

class EditApparatusRoute extends Route {
  @service declare store: Store;

  model() {
    return this.modelFor('equipment.apparatus');
  }
}

class EditApparatusTemplate extends Component<{
  Args: { model: { request: Future<ReactiveDataDocument<Apparatus>> } };
}> {
  @service declare store: Store;
  @service declare router: RouterService;
  @service declare intl: IntlService;

  submit = async (record: Apparatus & ReactiveResource, changes: Equipment) => {
    return withValidation(
      async () => {
        const result = await this.store.request<ReactiveDataDocument<Apparatus>>({
          ...editApparatus(await checkout(record), changes as Apparatus, { store: this.store }),
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
      @title={{t "equipment.pages.edit-apparatus.title"}}
      @description={{t "equipment.basic.apparatus.explanation"}}
    >
      <Request @request={{@model.request}}>
        <:content as |result|>
          <EquipmentForm
            @equipment={{result.data}}
            @submit={{fn this.submit (asReactiveApparatusResource result.data)}}
          />
        </:content>
      </Request>
    </Page>
  </template>
}

export { EditApparatusRoute, EditApparatusTemplate };
