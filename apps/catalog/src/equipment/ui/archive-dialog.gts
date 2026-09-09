import Component from '@glimmer/component';

import { Dialog } from '@sportipedia/ui';
import { t } from 'ember-intl';

import { Button } from '@hokulea/ember';

import type { Equipment } from '../domain-objects/equipment';

export interface ArchiveDialogSignature {
  Element: HTMLDialogElement;
  Args: {
    equipment: Equipment;
    confirm: () => void;
  };
}

export class ArchiveDialog extends Component<ArchiveDialogSignature> {
  close = (returnValue?: string) => {
    if (returnValue === 'confirm') {
      this.args.confirm();
    }
  };

  <template>
    <Dialog @close={{this.close}} ...attributes>
      <:header>
        {{t "equipment.ui.archive-dialog.title" name=@equipment.title}}
      </:header>
      <:body>
        {{t "equipment.ui.archive-dialog.body" name=@equipment.title}}
      </:body>
      <:footer as |diag|>
        <Button @push={{diag.close}} @importance="subtle">
          {{t "equipment.ui.archive-dialog.actions.cancel"}}
        </Button>
        <Button @push={{fn diag.close "confirm"}} @intent="danger">
          {{t "equipment.ui.archive-dialog.actions.archive"}}
        </Button>
      </:footer>
    </Dialog>
  </template>
}
