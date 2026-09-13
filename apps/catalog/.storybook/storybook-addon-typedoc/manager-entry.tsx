import { addons } from 'storybook/manager-api';

import { makeRenderLabel } from './label';
import './manager.css';

import type { ResolvedTypedocOptions } from './types';

/** configure the typedoc sidebar — called from the generated manager entry with main.ts options */
export function setupTypedocManager(config: ResolvedTypedocOptions): void {
  addons.setConfig({
    sidebar: {
      filters: {
        'hide-apidoc-index-pages': (entry: { tags?: string[] }) =>
          !(config.hideIndexPages && entry.tags?.includes('api-index'))
      },
      renderLabel: makeRenderLabel(config)
    }
  });
}
