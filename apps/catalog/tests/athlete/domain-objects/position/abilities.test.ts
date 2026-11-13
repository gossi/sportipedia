import { expect, test } from 'vitest';

import {
  canArchivePosition,
  canCatalogPosition,
  canEditPosition
} from '#/athlete/domain-objects/position/abilities';
import { UNICYCLE_RIDING } from '#athlete-test-support';
import { ADMIN, GUEST, USER } from '#tests/user/support/fixtures';

test('canCatalogPosition()', () => {
  expect(canCatalogPosition(GUEST)).toBeFalsy();
  expect(canCatalogPosition(USER)).toBeTruthy();
  expect(canCatalogPosition(ADMIN)).toBeTruthy();
});

test('canEditPosition()', () => {
  expect(canEditPosition(UNICYCLE_RIDING, GUEST)).toBeFalsy();
  expect(canEditPosition(UNICYCLE_RIDING, USER)).toBeTruthy();
  expect(canEditPosition(UNICYCLE_RIDING, ADMIN)).toBeTruthy();
});

test('canArchivePosition()', () => {
  expect(canArchivePosition(UNICYCLE_RIDING, GUEST)).toBeFalsy();
  expect(canArchivePosition(UNICYCLE_RIDING, USER)).toBeFalsy();
  expect(canArchivePosition(UNICYCLE_RIDING, ADMIN)).toBeTruthy();
});
