import { expect, test } from 'vitest';

import {
  canCreateExercise
} from '#/exercises/domain-objects/exercise/abilities';
import { ADMIN, GUEST, USER } from '#tests/user/support/fixtures';

test('canCreateExercise()', () => {
  expect(canCreateExercise(ADMIN)).toBeTruthy();
  expect(canCreateExercise(GUEST)).toBeFalsy();
  expect(canCreateExercise(USER)).toBeTruthy();
});

