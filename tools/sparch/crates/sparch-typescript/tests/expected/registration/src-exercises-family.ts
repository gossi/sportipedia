/**
 * @module Public API
 * @mergeModuleWith exercises
 */
import { exerciseSchema } from './schemas/exercise.ts';
import { exerciseTagSchema } from './schemas/exercise-tag.ts';

import type { SchemaService } from '@warp-drive/core/reactive';

/**
 * @category Public API
 */
export type { Exercise } from './domain-objects/exercise/exercise.ts';

// Modules

// Routes

// Data

/**
 * @internal
 */
export function configureExercisesSchema(schema: SchemaService) {
  schema.registerResources([exerciseSchema, exerciseTagSchema]);
}

/**
 * @category Public API
 */
export type { ExerciseTag } from './domain-objects/exercise-tag/exercise-tag.ts';

