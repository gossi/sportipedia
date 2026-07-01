import { concat } from '@ember/helper';

import { t } from 'ember-intl';

import { type Equipment, getType } from '../domain-objects/equipment';

import type { TOC } from '@ember/component/template-only';

interface EquipmentTypeSignature {
  Args: {
    equipment: Equipment;
  };
}

const EquipmentType: TOC<EquipmentTypeSignature> = <template>
  {{#let (getType @equipment) as |type|}}
    {{#if type}}
      {{t (concat "equipment.basic.type." type)}}
    {{/if}}
  {{/let}}
</template>;

export { EquipmentType };
