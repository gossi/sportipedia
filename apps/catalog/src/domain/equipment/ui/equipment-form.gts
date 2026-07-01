import Component from '@glimmer/component';
import { concat } from '@ember/helper';

import { SlugField } from '@sportipedia/ui';
import { t } from 'ember-intl';

import { Form, type FormValidationHandler } from '@hokulea/ember';

import type { Equipment } from '../domain-objects/equipment';
import type { ReactiveResource } from '@warp-drive/core/reactive';

interface EquipmentFormSignature {
  Element: HTMLFormElement;
  Args: {
    equipment?: Equipment | (Equipment & ReactiveResource);
    submit?: (data: Equipment) => void;
    validate?: FormValidationHandler<Equipment>;
  };
}

class EquipmentForm extends Component<EquipmentFormSignature> {
  SlugField = SlugField<Equipment>;

  setBase?: (base: string) => void;

  generateSlug = (event: Event) => {
    this.setBase?.((event.target as HTMLInputElement).value);
  };

  registerSetBase = (setBase: (base: string) => void) => {
    this.setBase = setBase;
  };

  <template>
    <Form @data={{@equipment}} @submit={{@submit}} @validate={{@validate}} ...attributes as |f|>
      <f.Text
        @name="title"
        @label={{t "equipment.ui.equipment-form.title"}}
        required
        {{on "input" this.generateSlug}}
      />

      <this.SlugField
        @form={{f}}
        @name="slug"
        @label={{t "equipment.ui.equipment-form.slug"}}
        @registerSetBase={{this.registerSetBase}}
        required
      />

      <f.TextArea @name="description" @label={{t "equipment.ui.equipment-form.description"}} />

      <f.Submit>
        {{t (concat "equipment.ui.equipment-form.actions." (if @equipment.id "edit" "catalog"))}}
      </f.Submit>
    </Form>
  </template>
}

export { EquipmentForm };
