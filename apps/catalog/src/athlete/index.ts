/**
 * @module Public API
 * @mergeModuleWith athlete
 */
import { positionSchema } from './schemas/position.ts';

import type { SchemaService } from '@warp-drive/core/reactive';

/**
 * @category Public API
 */
export type { Position } from './domain-objects/position/position.ts';

// Modules

// Routes

// Data

/**
 * @internal
 */
export function configureAthleteSchema(schema: SchemaService) {
  schema.registerResources([positionSchema]);
}
