import { buildRegistry } from 'ember-strict-application-resolver/build-registry';

import { buildRoutes } from '#/support/routing';

import { ApparatusRoute, ApparatusTemplate } from './pages/apparatus.gts';
import { CatalogApparatusTemplate } from './pages/catalog-apparatus.gts';
import { EditApparatusRoute, EditApparatusTemplate } from './pages/edit-apparatus.gts';
import { EditInstrumentRoute, EditInstrumentTemplate } from './pages/edit-instrument.gts';
import { InstrumentRoute, InstrumentTemplate } from './pages/instrument.gts';
import { OverviewRoute, OverviewTemplate } from './pages/overview.gts';

export type { Apparatus } from './domain-objects/apparatus/apparatus.ts';
export type { Instrument } from './domain-objects/instrument/instrument.ts';
import { CatalogInstrumentTemplate } from './pages/catalog-instrument.gts';
import { apparatusSchema } from './schemas/apparatus';
import { instrumentSchema } from './schemas/instrument';

import type { SchemaService } from '@warp-drive/core/reactive';

// Modules

export const equipmentRegistry = buildRegistry({
  './routes/equipment/instrument': InstrumentRoute,
  './routes/equipment/instrument/edit': EditInstrumentRoute,
  './routes/equipment/apparatus': ApparatusRoute,
  './routes/equipment/apparatus/edit': EditApparatusRoute,
  './routes/equipment': OverviewRoute,
  './templates/equipment': OverviewTemplate,
  './templates/equipment/catalog-apparatus': CatalogApparatusTemplate,
  './templates/equipment/catalog-instrument': CatalogInstrumentTemplate,
  './templates/equipment/instrument/index': InstrumentTemplate,
  './templates/equipment/instrument/edit': EditInstrumentTemplate,
  './templates/equipment/apparatus/index': ApparatusTemplate,
  './templates/equipment/apparatus/edit': EditApparatusTemplate
});

// Routes

export const equipmentRoutes = buildRoutes(function () {
  /* eslint-disable @typescript-eslint/no-invalid-this, unicorn/no-this-outside-of-class */
  this.route('equipment', function () {
    this.route('catalog-apparatus');
    this.route('catalog-instrument');

    this.route('apparatus', { path: 'apparatus/:apparatus' }, function () {
      this.route('edit');
    });

    this.route('instrument', { path: 'instrument/:instrument' }, function () {
      this.route('edit');
    });
  });
  /* eslint-enable @typescript-eslint/no-invalid-this, unicorn/no-this-outside-of-class */
});

// Data

export function configureEquipmentSchema(schema: SchemaService) {
  schema.registerResources([apparatusSchema, instrumentSchema]);
}
