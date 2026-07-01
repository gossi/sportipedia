import Component from '@glimmer/component';
import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { Request } from '@warp-drive/ember';
import { type IntlService, t } from 'ember-intl';

import { handleErrorResponse, makeMessageTranslator } from '#support/data/validation.ts';

import { Page } from '@hokulea/ember';

import { editApparatus } from '../domain-objects/apparatus/actions';
import { EquipmentForm } from '../ui/equipment-form.gts';

import type { Apparatus } from '../domain-objects/apparatus/apparatus';
import type { Equipment } from '../domain-objects/equipment';
import type RouterService from '@ember/routing/router-service';
import type { ReactiveDataDocument, ReactiveResource } from '@warp-drive/core/reactive';
import type { Future } from '@warp-drive/core/request';
import type { StructuredErrorDocument } from '@warp-drive/core/types/request';
import type Store from '#/services/store';
import type { JsonApiErrorResponse } from '#support/data/jsonapi.ts';

function asReactiveResource(record: Apparatus): ReactiveResource & Apparatus {
  return record as ReactiveResource & Apparatus;
}

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
    try {
      await editApparatus(record, changes as Apparatus, { store: this.store });

      // maybe re-reroute
      if (record.slug !== changes.slug) {
        this.router.transitionTo('equipment.apparatus.edit', changes.slug);
      }
    } catch (error) {
      return handleErrorResponse(error as StructuredErrorDocument<JsonApiErrorResponse>, {
        message: makeMessageTranslator('equipment.ui.equipment-form.errors', this.intl)
      });
    }
  };

  <template>
    <Page @title={{t "equipment.pages.edit-apparatus.title"}}>
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

export { EditApparatusRoute, EditApparatusTemplate };
