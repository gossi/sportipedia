import Component from '@glimmer/component';
import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { Request } from '@warp-drive/ember';
import { type IntlService, t } from 'ember-intl';

import { handleErrorResponse, makeMessageTranslator } from '#support/data/validation.ts';

import { Page } from '@hokulea/ember';

import { editInstrument } from '../domain-objects/instrument/actions';
import { EquipmentForm } from '../ui/equipment-form.gts';

import type { Equipment } from '../domain-objects/equipment';
import type { Instrument } from '../domain-objects/instrument/instrument';
import type RouterService from '@ember/routing/router-service';
import type { ReactiveDataDocument, ReactiveResource } from '@warp-drive/core/reactive';
import type { Future } from '@warp-drive/core/request';
import type { StructuredErrorDocument } from '@warp-drive/core/types/request';
import type Store from '#/services/store';
import type { JsonApiErrorResponse } from '#support/data/jsonapi.ts';

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
    try {
      await editInstrument(record, changes as Instrument, { store: this.store });

      // maybe re-reroute
      if (record.slug !== changes.slug) {
        this.router.transitionTo('equipment.instrument.edit', changes.slug);
      }
    } catch (error) {
      return handleErrorResponse(error as StructuredErrorDocument<JsonApiErrorResponse>, {
        message: makeMessageTranslator('equipment.ui.equipment-form.errors', this.intl)
      });
    }
  };

  <template>
    <Page @title={{t "equipment.pages.edit-instrument.title"}}>
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
