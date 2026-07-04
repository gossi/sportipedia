import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { helper } from '@ember/component/helper';
import { uniqueId } from '@ember/helper';

import { modifier } from 'ember-modifier';

import type { HelperLike, ModifierLike } from '@glint/template';

interface DialogApi {
  close: HTMLDialogElement['close'];
  requestClose: HTMLDialogElement['requestClose'];
}

interface DialogSignature {
  Element: HTMLDialogElement;
  Args: {
    close?: (returnValue: string) => void;
    // cancel?: () => void;
  };
  Blocks: {
    default: [DialogApi];
    header: [DialogApi];
    body: [DialogApi];
    footer: [DialogApi];
  };
}

class Dialog extends Component<DialogSignature> {
  declare private element: HTMLDialogElement;

  private ref = modifier((dialog: HTMLDialogElement) => {
    this.element = dialog;

    const closeHandler = (event: Event) => {
      this.args.close?.((event.target as HTMLDialogElement).returnValue);
    };

    this.element.addEventListener('close', closeHandler);

    return () => {
      this.element.removeEventListener('close', closeHandler);
    };
  });

  close: HTMLDialogElement['close'] = (returnValue?: string) => this.element.close(returnValue);
  requestClose: HTMLDialogElement['close'] = (returnValue?: string) =>
    this.element.requestClose(returnValue);

  <template>
    <style scoped>
      .dialog {
        /*background-color: var(--surface-window);*/
        background-color: var(--surface-base);
        margin: auto;
        margin-block-start: 40vh;
        min-width: 50vw;
        /*border-radius: var(--shape-radius-containeru);
      border: var(--shape-stroke);*/
        box-shadow: var(--shape-shadow-container);

        &::backdrop {
          opacity: 0.2;
          background: #000;
        }

        [part="header"] {
          background-color: var(--surface-container1);
        }

        [part="body"] {
        }

        [part="footer"] {
          background-color: var(--surface-container);
          display: flex;
          justify-content: flex-end;
          gap: var(--spacing-primitive-2);
          padding-inline: var(--spacing-container0);
          padding-block: var(--spacing-container-2);
        }

        [part="body"],
        [part="header"] {
          padding: var(--spacing-container0);
        }
      }
    </style>
    <dialog class="dialog" {{this.ref}} ...attributes>
      {{#let (hash close=this.close requestClose=this.requestClose) as |api|}}
        {{#if (has-block "header")}}
          <div part="header">
            {{yield api to="header"}}
          </div>
        {{/if}}

        {{#if (or (has-block "body") (has-block "default"))}}
          <div part="body">
            {{#if (has-block "body")}}
              {{yield api to="body"}}
            {{else if (has-block "default")}}
              {{yield api}}
            {{/if}}
          </div>
        {{/if}}

        {{#if (has-block "footer")}}
          <div part="footer">
            {{yield api to="footer"}}
          </div>
        {{/if}}
      {{/let}}
    </dialog>
  </template>
}

class State {
  @tracked id = uniqueId();
  @tracked opened = false;
}

interface OpenDialogArgs {
  modal?: boolean;
}

type OpenDialog = HelperLike<{
  Args: {
    Named: OpenDialogArgs;
  };
  Return: {
    trigger: ModifierLike<{ Element: HTMLElement }>;
    target: ModifierLike<{ Element: HTMLDialogElement }>;
  };
}>;

const openDialog: OpenDialog = helper((_, args: OpenDialogArgs) => {
  const state = new State();
  // let targetElement: HTMLElement | undefined;

  return {
    trigger: modifier((element: HTMLElement) => {
      element.setAttribute('commandfor', state.id);
      element.setAttribute('command', args.modal ? 'show-modal' : 'show');
    }),
    target: modifier((element: HTMLElement, __, ___) => {
      if (element.id) {
        state.id = element.id;
      } else {
        element.id = state.id;
      }

      // element.setAttribute('popover', manual ? 'manual' : '');
      // element.dataset.position = position;
      // element.dataset.fallback = fallback;
      // // @ts-expect-error doesn't know that CSS yet
      // element.style.anchorName = `--${state.id}`;
      // // @ts-expect-error doesn't know that CSS yet
      // element.style.positionArea = position;
      // targetElement = element;

      // const toggleHandler = (event: ToggleEvent) => {
      //   state.opened = event.newState === 'open';

      //   if (event.newState === 'open') {
      //     opened?.();
      //   } else if (event.newState === 'closed') {
      //     closed?.();
      //   }
      // };

      // element.addEventListener('toggle', toggleHandler);

      // return () => {
      //   element.removeEventListener('toggle', toggleHandler);
      // };
    })
    // get opened() {
    //   return state.opened;
    // },
    // open: () => {
    //   targetElement?.showPopover();
    // },
    // close: () => {
    //   targetElement?.hidePopover();
    // }
  };
});

export { Dialog, openDialog };
