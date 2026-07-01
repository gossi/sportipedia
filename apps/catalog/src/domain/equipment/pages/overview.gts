import Component from '@glimmer/component';
import Route from '@ember/routing/route';
import { service } from '@ember/service';

import { ability } from 'ember-ability';
import { t } from 'ember-intl';

import PlusIcon from '~icons/ph/plus-bold';

import { Button, Icon, NavigationList, SectionedPage } from '@hokulea/ember';

import { canCatalogApparatus as upstreamCanCatalogApparatus } from '../domain-objects/apparatus/abilities';
import { readApparatuses } from '../domain-objects/apparatus/queries';
import { type Equipment, getType } from '../domain-objects/equipment';
import { canCatalogInstrument as upstreamCanCatalogInstrument } from '../domain-objects/instrument/abilities';
import { readInstruments } from '../domain-objects/instrument/queries';
import { EquipmentType } from '../ui/equipment-type.gts';

import type { Apparatus } from '../domain-objects/apparatus/apparatus';
import type { Instrument } from '../domain-objects/instrument/instrument';
import type Store from '#/services/store';

class OverviewRoute extends Route {
  @service declare store: Store;

  model() {
    void this.store.request(readApparatuses());
    void this.store.request(readInstruments());
  }
}

const canCatalogApparatus = ability(
  ({ services }) =>
    () =>
      upstreamCanCatalogApparatus(services.auth.user)
);

const canCatalogInstrument = ability(
  ({ services }) =>
    () =>
      upstreamCanCatalogInstrument(services.auth.user)
);

class OverviewTemplate extends Component {
  @service declare store: Store;

  get apparatuses(): Apparatus[] {
    return this.store.peekAll('apparatuses') as unknown as Apparatus[];
  }

  get instruments(): Instrument[] {
    return this.store.peekAll('instruments') as unknown as Instrument[];
  }

  get equipment(): Equipment[] {
    return [...this.apparatuses, ...this.instruments].toSorted((a, b) =>
      a.title.localeCompare(b.title)
    );
  }

  <template>
    <style scoped>
      .equipment-layout {
        display: grid;

        grid-template-columns: 33% auto;
        gap: var(--spacing-container0);
      }

      .type {
        margin-inline-start: auto;
        color: var(--typography-muted);
        font-size: var(--ls-1);
      }

      .content {
        display: flex;
        flex-direction: column;
        gap: var(--spacing-container0);
      }

      .nav [part="item"] > span {
        display: inline-flex;
        align-items: center;
        width: 100%;
      }
    </style>
    <SectionedPage
      @title={{t "equipment.pages.overview.title"}}
      @description={{t "equipment.pages.overview.description"}}
    >
      <div>
        {{#if (canCatalogInstrument)}}
          <Button @href="/equipment/catalog-instrument">
            <:before><Icon @icon={{PlusIcon}} /></:before>
            <:label>{{t "equipment.pages.overview.actions.catalog-instrument"}}</:label>
          </Button>
        {{/if}}

        {{#if (canCatalogApparatus)}}
          <Button @href="/equipment/catalog-apparatus">
            <:before><Icon @icon={{PlusIcon}} /></:before>
            <:label>{{t "equipment.pages.overview.actions.catalog-apparatus"}}</:label>
          </Button>
        {{/if}}
      </div>
      <div class="equipment-layout">
        <NavigationList class="nav" as |n|>
          {{#each this.equipment as |e|}}
            <n.Item @href="/equipment/{{getType e}}/{{e.slug}}">
              {{e.title}}

              <span class="type"><EquipmentType @equipment={{e}} /></span>
            </n.Item>
          {{/each}}
        </NavigationList>

        <div class="content">
          {{outlet}}
        </div>
      </div>
    </SectionedPage>
  </template>
}

export { OverviewRoute, OverviewTemplate };
