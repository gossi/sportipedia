import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { next } from '@ember/runloop';

import { t } from 'ember-intl';
import { modifier } from 'ember-modifier';

import { Button, InputBuilder, TextInput } from '@hokulea/ember';

import { manageValidation } from './manage-validation';

import type Owner from '@ember/owner';
import type { FormBuilder } from '@hokulea/ember';

function toSlug(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replaceAll(/[^a-z0-9\s-]/g, '')
    .replaceAll(/\s+/g, '-')
    .replaceAll(/-+/g, '-')
    .replaceAll(/^-|-$/g, '');
}

// const not = (val: boolean) => !val;s
const or = (a: boolean, b: boolean) => a || b;

interface SlugFieldSignature<T extends object = object> {
  Element: HTMLInputElement;
  Args: {
    form: FormBuilder<T>;
    name: string;
    label?: string;
    // linkedField: string;
    prefix?: string;
    registerSetBase?: (setBase: (value: string) => void) => void;
  };
}

// ugh, this is not pretty at all
// see here:
// - https://github.com/hokulea/hokulea/issues/620
// - https://github.com/hokulea/hokulea/issues/621
export class SlugField<T extends object = object> extends Component<SlugFieldSignature<T>> {
  @tracked mode: 'auto' | 'manual' = 'auto';

  baseValue?: string;
  inputElement?: HTMLInputElement;
  editButton?: HTMLButtonElement;
  setValue?: (val: string) => void;

  get manual(): boolean {
    return this.mode === 'manual';
  }

  get auto(): boolean {
    return this.mode === 'auto';
  }

  constructor(owner: Owner, args: SlugFieldSignature<T>['Args']) {
    super(owner, args);

    args.registerSetBase?.(this.generateSlugAPI);
  }

  generateSlugAPI = (name: string): void => {
    this.baseValue = name;

    if (this.auto) {
      this.setValue?.(toSlug(name));
    }
  };

  switchToManual = (): void => {
    this.mode = 'manual';

    // eslint-disable-next-line ember/no-runloop
    next(() => {
      this.inputElement?.focus();
    });
  };

  switchToAuto = (): void => {
    this.mode = 'auto';

    this.setValue?.(this.#generateSlug());

    // eslint-disable-next-line ember/no-runloop
    next(() => {
      this.editButton?.focus();
    });
  };

  updateValue = (value: string): void => {
    this.setValue?.(value);
  };

  #generateSlug() {
    return toSlug(this.baseValue ?? '');
  }

  private refInput = modifier((element: HTMLInputElement) => {
    this.inputElement = element;
  });

  private refEdit = modifier((element: HTMLButtonElement) => {
    this.editButton = element;
  });

  private connectSetValue = (setValue: (val: string) => void) => {
    this.setValue = setValue;
  };

  <template>
    <style scoped>
      .box {
        &[data-mode="auto"] {
          background-color: var(--control-disabled-background);
        }
      }

      .prefix {
        color: var(--typography-subtle);
        font-family: var(--typography-monospace-family);
        padding-inline-end: var(--spacing-primitive-4);
      }

      .slug {
        font-family: var(--typography-monospace-family);
        flex: 1;
      }

      .button {
        padding: 0;
        border: 0;
        border-radius: var(--shape-stroke-width);
        outline-offset: var(--spacing-primitive-4);
      }

      .hidden {
        visibility: hidden;
      }
    </style>

    <@form.Field
      @name={{@name}}
      @label={{or @label "Slug"}}
      {{!-- @validate={{this.validateField}} --}}
      {{!-- @linkedField={{@linkedField}} --}}
      {{! @revalidateOn="input" }}
      as |f|
    >
      {{! @glint-ignore }}
      {{this.connectSetValue f.setValue}}

      <InputBuilder class="box" data-mode={{if this.manual "manual" "auto"}} as |b|>
        <b.Affix class="prefix">{{or @prefix "/"}}</b.Affix>

        <TextInput
          {{! @glint-ignore }}
          @value={{f.value}}
          @update={{this.updateValue}}
          {{!-- @disabled={{@disabled}} --}}
          name={{@name}}
          id={{f.id}}
          class="slug"
          {{! @glint-ignore }}
          {{this.refInput}}
          {{! @glint-ignore }}
          {{f.registerElement}}
          {{! @glint-ignore }}
          {{manageValidation errorMessageId=f.errorId invalid=f.invalid showErrors=f.showErrors}}
          inert={{this.auto}}
          ...attributes
        />

        <b.Affix>
          {{#if this.auto}}
            <Button
              @push={{this.switchToManual}}
              @importance="plain"
              class="button"
              {{! @glint-ignore }}
              {{this.refEdit}}
            >
              {{t "ui.slug-field.actions.edit"}}
            </Button>
          {{else}}
            <Button @push={{this.switchToAuto}} @importance="plain" class="button">Auto</Button>
          {{/if}}

        </b.Affix>
      </InputBuilder>
    </@form.Field>
  </template>
}
