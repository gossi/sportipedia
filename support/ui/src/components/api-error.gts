import { Card } from '@hokulea/ember';

import type { TOC } from '@ember/component/template-only';

const ApiError: TOC<{
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  Args: { error?: any };
}> = <template>
  <style scoped>
    .error {
      background-color: var(--indicator-error-subtle-background);
      border-color: var(--indicator-error-subtle-border);
      color: var(--indicator-error-subtle-text);
    }
  </style>
  <Card class="error">
    <p>Hoppla, an Error happened.</p>

    {{#if @error}}
      <p>{{@error}}</p>
    {{/if}}
  </Card>
</template>;

export { ApiError };
