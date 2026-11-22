/**
 * @module Public API
 * @mergeModuleWith equipment
 */
import { instrumentSchema } from './schemas/instrument.ts';
import { apparatusSchema } from './schemas/apparatus.ts';
import { apparatusCertificationSchema } from './schemas/apparatus-certification.ts';
import { tagSchema } from './schemas/tag.ts';

import type { SchemaService } from '@warp-drive/core/reactive';

/**
 * @category Public API
 */
export type { Instrument } from './domain-objects/instrument/instrument.ts';

// Modules

// Routes

// Data

/**
 * @internal
 */
export function configureEquipmentSchema(schema: SchemaService) {
  schema.registerResources([instrumentSchema, apparatusSchema, apparatusCertificationSchema, tagSchema]);
}

/**
 * @category Public API
 */
export type { Apparatus } from './domain-objects/apparatus/apparatus.ts';

/**
 * @category Public API
 */
export type { ApparatusCertification } from './domain-objects/apparatus-certification/apparatus-certification.ts';

/**
 * @category Public API
 */
export type { Tag } from './domain-objects/tag/tag.ts';



