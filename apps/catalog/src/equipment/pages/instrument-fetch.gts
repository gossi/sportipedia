import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

import type Owner from '@ember/owner';

interface InstrumentPayload {
  name: string;
  description: string;
}

class InstrumentFetch extends Component {
  @tracked data: InstrumentPayload | undefined = undefined;
  @tracked error: Error | undefined = undefined;

  constructor(owner: Owner, args: object) {
    super(owner, args);
    void this.load();
  }

  async load() {
    try {
      const response = await fetch('/api/instrument');

      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`);
      }

      this.data = (await response.json()) as InstrumentPayload;
    } catch (error) {
      this.error = error as Error;
    }
  }

  <template>
    <style scoped>
      .card {
        display: grid;
        gap: var(--spacing-container0);
        max-inline-size: 40ch;
      }
    </style>

    {{#if this.error}}
      <p role="alert">{{this.error.message}}</p>
    {{else if this.data}}
      <div class="card">
        <h2>{{this.data.name}}</h2>
        <p>{{this.data.description}}</p>
      </div>
    {{else}}
      <p>Loading instrument…</p>
    {{/if}}

    {{outlet}}
  </template>
}

export { InstrumentFetch };
