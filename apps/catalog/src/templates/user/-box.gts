import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

import { element } from 'ember-element-helper';
import { modifier } from 'ember-modifier';
import { or } from 'ember-truth-helpers';

import { Button, Icon } from '@hokulea/ember';

import type { TOC } from '@ember/component/template-only';
import type { ComponentLike, WithBoundArgs } from '@glint/template';

type IconComponent = ComponentLike<{
  Element: SVGElement;
}>;

interface BoxItemSignature {
  Args: {
    icon?: string | IconComponent;
    openLabel?: string;
    closeLabel?: string;
  };
  Blocks: {
    default: [];
    content: [];
    actions: [WithBoundArgs<typeof Button, 'importance' | 'spacing'>];
    disclosure: [];
  };
}

class BoxItem extends Component<BoxItemSignature> {
  @tracked open = false;
  detailsElement?: HTMLDetailsElement;

  toggle = () => {
    if (this.detailsElement) {
      this.detailsElement.open = !this.detailsElement.open;
    }
  };

  // eslint-disable-next-line unicorn/consistent-function-scoping
  ref = modifier((elem: HTMLElement) => {
    if (elem instanceof HTMLDetailsElement) {
      this.detailsElement = elem;

      const handler = (e: ToggleEvent) => {
        this.open = e.newState === 'open';
      };

      elem.addEventListener('toggle', handler);

      return () => {
        elem.removeEventListener('toggle', handler);
      };
    }
  });

  <template>
    <style scoped>
      .item {
        background-color: var(--surface-container);
        border-inline: var(--shape-stroke);
        border-block-start: var(--shape-stroke);
        padding: var(--spacing-container0);

        &:first-child {
          border-start-start-radius: var(--shape-radius-container);
          border-start-end-radius: var(--shape-radius-container);
        }

        &:last-child {
          border-block-end: var(--shape-stroke);
          border-end-start-radius: var(--shape-radius-container);
          border-end-end-radius: var(--shape-radius-container);
        }
      }

      .summary {
        display: flex;
        align-items: center;
        gap: var(--s-3);

        :global(small) {
          font-size: var(--ls-1);
          color: var(--typography-muted);
        }

        [data-icon] {
          font-size: var(--s2);
          width: var(--s2);
        }
      }

      .actions {
        font-size: var(--ls-1);
        margin-inline-start: auto;
      }

      .disclosure {
        font-size: var(--ls-1);
        padding-block-start: var(--s0);
      }

      .summary:has([data-icon]) + .disclosure {
        padding-inline-start: calc(var(--s2) + var(--s-4));
      }
    </style>
    {{#let (element (if (has-block "disclosure") "details" "div")) as |Container|}}
      <Container class="item" {{this.ref}}>
        {{#let (element (if (has-block "disclosure") "summary" "span")) as |Summary|}}
          <Summary class="summary">
            {{#if @icon}}
              <Icon @icon={{@icon}} data-icon />
            {{/if}}

            <span>

              {{yield}}
              {{yield to="content"}}
            </span>

            {{#if (or (has-block "disclosure") (has-block "actions"))}}
              <span class="actions">
                {{#let (component Button spacing="-1" importance="subtle") as |Action|}}
                  {{#if (has-block "disclosure")}}
                    <Action @push={{this.toggle}} role="presentation">
                      {{#if this.open}}
                        {{@closeLabel}}
                      {{else}}
                        {{@openLabel}}
                      {{/if}}
                    </Action>
                  {{else if (has-block "actions")}}
                    {{yield Action to="actions"}}
                  {{/if}}
                {{/let}}
              </span>
            {{/if}}
          </Summary>

          {{#if (has-block "disclosure")}}
            <div class="disclosure">
              {{yield to="disclosure"}}
            </div>
          {{/if}}
        {{/let}}
      </Container>
    {{/let}}
  </template>
}

export const BoxList: TOC<{ Blocks: { default: [typeof BoxItem] } }> = <template>
  <style scoped>
    .boxlist {
    }
  </style>
  <div class="boxlist">
    {{yield BoxItem}}
  </div>
</template>;
