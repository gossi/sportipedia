/**
 * Shared types for storybook-addon-typedoc.
 *
 * Must not import anything runtime-related: it is consumed from the node (preset),
 * the manager (sidebar entries), and the preview bundles alike.
 */
export type IconScope = 'leaf' | 'all';

export interface TypedocAddonOptions {
  /**
   * Badge leaf pages only (`leaf`) or also groups inheriting a kind from their children (`all`).
   *
   * @default 'leaf'
   */
  iconScope?: IconScope;
  /**
   * Hide module + package readme index pages (tagged `api-index`) from the sidebar.
   *
   * @default true
   */
  hideIndexPages?: boolean;
  /**
   * Markdown output directory to read, relative to the Storybook config dir.
   *
   * @default '../apidocs/markdown'
   */
  markdownDir?: string;
  /**
   * TypeDoc JSON structure file used to derive titles/tags, relative to the Storybook config dir.
   *
   * @default '../apidocs/structure.json'
   */
  structureFile?: string;
}

/** Fully resolved addon options as used by the node and manager sides. */
export interface ResolvedTypedocOptions {
  iconScope: IconScope;
  hideIndexPages: boolean;
}
