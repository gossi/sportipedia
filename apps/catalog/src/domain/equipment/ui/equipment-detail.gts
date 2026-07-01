import { t } from 'ember-intl';

import ArchiveBoxIcon from '~icons/ph/archive-box?width=unset&height=unset';
import PencilSimpleIcon from '~icons/ph/pencil-simple?width=unset&height=unset';

import { Button, Icon } from '@hokulea/ember';

import type { Equipment } from '../domain-objects/equipment';
import type { TOC } from '@ember/component/template-only';

const EquipmentDetail: TOC<{
  Args: {
    equipment: Equipment;
    editingAllowed: boolean;
    archivingAllowed: boolean;
    editHref: string;
    archive?: () => void;
  };
}> = <template>
  <style scoped>
    .detail-layout {
      display: grid;
      grid-template-columns: auto max-content;
    }

    .slug {
      --flow-space: var(--spacing-container-4);
    }

    .actions {
      display: flex;
      flex-direction: column;
      gap: var(--spacing-container-3);
    }

    .no-desc {
      color: var(--typography-subtle);
    }
  </style>
  <div class="detail-layout">
    <div class="flow">

      <h1>{{@equipment.title}}</h1>

      <pre class="slug">/{{@equipment.slug}}</pre>

      {{#if @equipment.description}}
        <p>{{@equipment.description}}</p>
      {{else}}
        <p class="no-desc">{{t "equipment.ui.equipment-detail.no-description"}}</p>
      {{/if}}
    </div>
    <div class="actions">
      {{#if @editingAllowed}}
        <Button @href={{@editHref}}>
          <:before><Icon @icon={{PencilSimpleIcon}} /></:before>
          <:label>{{t "equipment.ui.equipment-detail.actions.edit"}}</:label>
        </Button>
      {{/if}}
      {{#if @archivingAllowed}}
        <Button @intent="danger">
          <:before><Icon @icon={{ArchiveBoxIcon}} /></:before>
          <:label>{{t "equipment.ui.equipment-detail.actions.archive"}}</:label>
        </Button>
      {{/if}}
    </div>
  </div>
</template>;

export { EquipmentDetail };
