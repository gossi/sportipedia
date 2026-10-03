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
   * Show all generated index pages (pages whose body is a listing of other pages).
   * Implicitly enables `showIndexPackage` and `showIndexModule`.
   *
   * @default false
   */
  showIndex?: boolean;
  /**
   * Show the package index page (`<package>/README.md`, tagged `api-index-package`).
   *
   * @default showIndex
   */
  showIndexPackage?: boolean;
  /**
   * Show the module index pages (`<package>/<module>/README.md`, tagged `api-index-module`).
   *
   * @default showIndex
   */
  showIndexModule?: boolean;
  /**
   * Render package index pages with only their public exports — the same
   * listing TypeDoc puts in the package README (its category/grouping,
   * entries linked to each symbol's own page) — instead of the full README.
   *
   * Packages without exports have their index page hidden entirely.
   *
   * @default false
   */
  packageIndexExportsOnly?: boolean;
  /**
   * Sidebar labels for the index pages, used as the leaf of their Storybook titles.
   *
   * @default { package: 'Package', module: 'Module' }
   */
  indexLabels?: {
    package?: string;
    module?: string;
  };
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
  showIndexPackage: boolean;
  showIndexModule: boolean;
  packageIndexExportsOnly: boolean;
  indexLabels: {
    package: string;
    module: string;
  };
}
