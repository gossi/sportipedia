import { LinkManagerService } from 'ember-link';
import PageTitleService from 'ember-page-title/services/page-title';

import { HokuleaService } from '@hokulea/ember';

import config from './config';
import Router from './router';

import type { ImportGlobFunction } from 'vite/types/importGlob.js';

function formatAsResolverEntries(imports: ReturnType<ImportGlobFunction>) {
  return Object.fromEntries(
    Object.entries(imports).map(([k, v]) => [
      k.replace(/\.g?(j|t)s$/, '').replace(/^\.\//, `${config.modulePrefix}/`),
      v
    ])
  );
}

/**
 * A global registry is needed until:
 * - Services can be referenced via import paths (rather than strings)
 * - we design a new routing system
 */
const appRegistry = {
  ...formatAsResolverEntries(import.meta.glob('./templates/**/*.{gjs,gts,js,ts}', { eager: true })),
  ...formatAsResolverEntries(import.meta.glob('./services/**/*.{js,ts}', { eager: true })),
  ...formatAsResolverEntries(import.meta.glob('./routes/**/*.{js,ts}', { eager: true })),
  [`${config.modulePrefix}/router`]: Router
};

const emberRegistry = {
  //   [`${config.modulePrefix}/modifiers/did-insert`]: didInsert as RenderModifier,
  //   [`${config.modulePrefix}/modifiers/did-update`]: didUpdate as RenderModifier,
  //   [`${config.modulePrefix}/modifiers/will-destroy`]: willDestroy as RenderModifier
};

const addonRegistry = {
  [`${config.modulePrefix}/services/page-title`]: PageTitleService,
  [`${config.modulePrefix}/services/-hokulea`]: HokuleaService,
  [`${config.modulePrefix}/services/link-manager`]: LinkManagerService
  // [`${config.modulePrefix}/services/-portal`]: PortalService
};

export const registry = {
  ...emberRegistry,
  ...addonRegistry,
  ...appRegistry
};
