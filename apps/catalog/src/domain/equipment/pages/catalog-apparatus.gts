import Component from '@glimmer/component';
import { service } from '@ember/service';

import { type IntlService, t } from 'ember-intl';

import { handleErrorResponse, makeMessageTranslator } from '#support/data/validation.ts';

import { Page } from '@hokulea/ember';

import { catalogApparatus } from '../domain-objects/apparatus/actions';
import { EquipmentForm } from '../ui/equipment-form.gts';

import type { Apparatus } from '../domain-objects/apparatus/apparatus';
import type { Equipment } from '../domain-objects/equipment';
import type { StructuredErrorDocument } from '@warp-drive/core/types/request';
import type Store from '#/services/store';
import type { JsonApiErrorResponse } from '#support/data/jsonapi';

export class CatalogApparatusTemplate extends Component {
  @service declare store: Store;
  @service declare intl: IntlService;

  submit = async (data: Equipment) => {
    try {
      await catalogApparatus(data as Apparatus, { store: this.store });
    } catch (error) {
      return handleErrorResponse(error as StructuredErrorDocument<JsonApiErrorResponse>, {
        message: makeMessageTranslator('equipment.ui.equipment-form.errors', this.intl)
      });
    }
  };

  <template>
    <Page @title={{t "equipment.pages.catalog-apparatus.title"}}>
      <EquipmentForm @submit={{this.submit}} />
    </Page>
  </template>
}
