import { addons } from 'storybook/manager-api';

import { renderLabel } from './components/label';

/** hide pages tagged `api-index` (module + package readme pages) from the sidebar */
const HIDE_INDEX_PAGES = true;

addons.setConfig({
  sidebar: {
    showRoots: false,
    filters: {
      'hide-apidoc-index-pages': (entry: { tags?: string[] }) =>
        !(HIDE_INDEX_PAGES && entry.tags?.includes('api-index'))
    },
    renderLabel
});
