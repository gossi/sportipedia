import { addons } from 'storybook/manager-api';

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore nobody wants JSX enabled
import { renderLabel } from './components/label';

/** hide pages tagged `api-index` (module + package readme pages) from the sidebar */
const HIDE_INDEX_PAGES = true;

addons.setConfig({
  sidebar: {
    // showRoots: false,
    filters: {
      'hide-apidoc-index-pages': (entry: { tags?: string[] }) =>
        // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
        !(HIDE_INDEX_PAGES && entry.tags?.includes('api-index'))
    },
    renderLabel
  }
});
