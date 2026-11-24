import { expect, test } from 'vitest';

import {
  canArchiveInstrument,
  canCatalogInstrument,
  canEditInstrument
} from '#/equipment/domain-objects/instrument/abilities';
import { UNICYCLE } from '#equipment-test-support';
import { ADMIN, GUEST, USER } from '#tests/user/support/fixtures';

test('canArchiveInstrument()', () => {
  expect(canArchiveInstrument(UNICYCLE, ADMIN)).toBeTruthy();
  expect(canArchiveInstrument(UNICYCLE, GUEST)).toBeFalsy();
  expect(canArchiveInstrument(UNICYCLE, USER)).toBeTruthy();
});

test('canCatalogInstrument()', () => {
  expect(canCatalogInstrument(ADMIN)).toBeTruthy();
  expect(canCatalogInstrument(GUEST)).toBeFalsy();
  expect(canCatalogInstrument(USER)).toBeTruthy();
});

test('canEditInstrument()', () => {
  expect(canEditInstrument(UNICYCLE, ADMIN)).toBeTruthy();
  expect(canEditInstrument(UNICYCLE, GUEST)).toBeFalsy();
  expect(canEditInstrument(UNICYCLE, USER)).toBeTruthy();
});

