/**
 * @module Public API
 * @mergeModuleWith athlete
 */
import { positionSchema } from './schemas/position.ts';

import type { SchemaService } from '@warp-drive/core/reactive';

// Modules

// Routes

// Data

/**
 * @category Public API
 */
export type { Position } from './domain-objects/position/position.ts';

/**
 * @internal
 */
export function configureAthleteSchema(schema: SchemaService) {
  schema.registerResources([positionSchema]);
}
