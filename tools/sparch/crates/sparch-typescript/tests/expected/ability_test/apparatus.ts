import { expect, test } from 'vitest';

import {
  canArchiveApparatus,
  canCatalogApparatus,
  canEditApparatus
} from '#/equipment/domain-objects/apparatus/abilities';
import { PARALLEL_BARS } from '#equipment-test-support';
import { ADMIN, GUEST, USER } from '#tests/user/support/fixtures';

test('canArchiveApparatus()', () => {
  expect(canArchiveApparatus(PARALLEL_BARS, ADMIN)).toBeTruthy();
  expect(canArchiveApparatus(PARALLEL_BARS, GUEST)).toBeFalsy();
  expect(canArchiveApparatus(PARALLEL_BARS, USER)).toBeTruthy();
});

test('canCatalogApparatus()', () => {
  expect(canCatalogApparatus(ADMIN)).toBeTruthy();
  expect(canCatalogApparatus(GUEST)).toBeFalsy();
  expect(canCatalogApparatus(USER)).toBeTruthy();
});

test('canEditApparatus()', () => {
  expect(canEditApparatus(PARALLEL_BARS, ADMIN)).toBeTruthy();
  expect(canEditApparatus(PARALLEL_BARS, GUEST)).toBeFalsy();
  expect(canEditApparatus(PARALLEL_BARS, USER)).toBeTruthy();
});

