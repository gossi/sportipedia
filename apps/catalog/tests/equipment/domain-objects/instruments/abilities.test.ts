import { expect, test } from 'vitest';

import {
  canArchiveInstrument,
  canCatalogInstrument,
  canEditInstrument
} from '#/equipment/domain-objects/instrument/abilities';
import { UNICYCLE } from '#tests/equipment/support/fixtures/instruments.ts';
import { ADMIN, GUEST, USER } from '#tests/user/support/fixtures';

test('canCatalogInstrument()', () => {
  expect(canCatalogInstrument(GUEST)).toBeFalsy();
  expect(canCatalogInstrument(USER)).toBeTruthy();
  expect(canCatalogInstrument(ADMIN)).toBeTruthy();
});

test('canEditInstrument()', () => {
  expect(canEditInstrument(UNICYCLE, GUEST)).toBeFalsy();
  expect(canEditInstrument(UNICYCLE, USER)).toBeTruthy();
  expect(canEditInstrument(UNICYCLE, ADMIN)).toBeTruthy();
});

test('canArchiveInstrument()', () => {
  expect(canArchiveInstrument(UNICYCLE, GUEST)).toBeFalsy();
  expect(canArchiveInstrument(UNICYCLE, USER)).toBeFalsy();
  expect(canArchiveInstrument(UNICYCLE, ADMIN)).toBeTruthy();
});
