import { t } from 'ember-intl';

import PlusIcon from '~icons/ph/plus-bold';

import { Button, Icon, Page } from '@hokulea/ember';

const IndexTemplate = <template>
  <style scoped>
    .empty {
      display: grid;
      gap: var(--spacing-container0);
    }

    .explanation {
      display: grid;
      grid-template-columns: 1fr min-content 1fr;
      gap: var(--spacing-container0);

      &:before {
        content: "";
        border: var(--shape-stroke);
        align-self: stretch;
      }

      & > * {
        display: flex;
        flex-direction: column;
        gap: var(--spacing-container0);
        flex: 1;

        &:first-child {
          order: -1;
        }

        a {
          margin-block-start: auto;
          justify-content: flex-start;
          padding: 0;
        }
      }
    }
  </style>
  <Page
    @title={{t "equipment.pages.index.title"}}
    @description={{t "equipment.pages.index.description"}}
  >
    <div class="explanation">
      <div>
        <h2>{{t "equipment.basic.instrument.label"}}</h2>
        <p>{{t "equipment.basic.instrument.explanation"}}</p>

        <Button @href="/equipment/catalog-instrument" @importance="plain">
          <:before><Icon @icon={{PlusIcon}} /></:before>
          <:label>{{t "equipment.pages.overview.actions.catalog-instrument"}}</:label>
        </Button>
      </div>

      <div>
        <h2>{{t "equipment.basic.apparatus.label"}}</h2>
        <p>{{t "equipment.basic.apparatus.explanation"}}</p>

        <Button @href="/equipment/catalog-apparatus" @importance="plain">
          <:before><Icon @icon={{PlusIcon}} /></:before>
          <:label>{{t "equipment.pages.overview.actions.catalog-apparatus"}}</:label>
        </Button>
      </div>
    </div>
  </Page>
  {{! <div class="empty">
    <h1></h1>
    

    
  </div> }}
</template>;

export { IndexTemplate };
