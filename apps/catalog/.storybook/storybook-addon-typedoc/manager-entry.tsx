import { addons } from 'storybook/manager-api';

import { makeRenderLabel } from './label';
import './manager.css';

import type { ResolvedTypedocOptions } from './types';

/** sidebar tags of the index page kinds, mapped to the option that shows them */
const INDEX_PAGE_TAGS = {
  'api-index-package': 'showIndexPackage',
  'api-index-module': 'showIndexModule'
} as const satisfies Record<string, keyof ResolvedTypedocOptions>;

/** configure the typedoc sidebar — called from the generated manager entry with main.ts options */
export function setupTypedocManager(config: ResolvedTypedocOptions): void {
  addons.setConfig({
    sidebar: {
      filters: {
        'hide-apidoc-index-pages': (entry: { tags?: string[] }) => {
          const tags = entry.tags ?? [];

          return !Object.entries(INDEX_PAGE_TAGS).some(
            ([tag, option]) => tags.includes(tag) && !config[option]
          );
        }
      },
      renderLabel: makeRenderLabel(config)
    }
  });
}
