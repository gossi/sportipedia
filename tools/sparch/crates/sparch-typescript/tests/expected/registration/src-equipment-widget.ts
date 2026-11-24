/**
 * @module Public API
 * @mergeModuleWith equipment
 */
import { widgetSchema } from './schemas/widget.ts';

import type { SchemaService } from '@warp-drive/core/reactive';

/**
 * @category Public API
 */
export type { Widget } from './domain-objects/widget/widget.ts';

// Modules

// Routes

// Data

/**
 * @internal
 */
export function configureEquipmentSchema(schema: SchemaService) {
  schema.registerResources([widgetSchema]);
}
