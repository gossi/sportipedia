import { Timestamps } from './traits';
import { TemporalDateTimeTransform, TemporalDateTransform } from './transforms';

import type { SchemaService } from '@warp-drive/core/reactive';

export function configureSchema(schema: SchemaService) {
  schema.registerTrait(Timestamps);
  schema.registerTransformation(TemporalDateTransform);
  schema.registerTransformation(TemporalDateTimeTransform);
}
